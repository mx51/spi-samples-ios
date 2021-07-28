//
//  SPIClient.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-28.
//  Copyright © 2017 mx51. All rights reserved.
//

#import "NSObject+Util.h"
#import "NSString+Util.h"
#import "NSDate+Util.h"
#import "NSDateFormatter+Util.h"
#import "SPICashout.h"
#import "SPIClient.h"
#import "SPIClient+Internal.h"
#import "SPIConnection.h"
#import "SPIKeyRollingHelper.h"
#import "SPILogger.h"
#import "SPIMessage.h"
#import "SPIModels.h"
#import "SPIPairing.h"
#import "SPIPairingHelper.h"
#import "SPIPayAtTable.h"
#import "SPIPingHelper.h"
#import "SPIPreAuth.h"
#import "SPITransaction.h"
#import "SPIPurchaseHelper.h"
#import "SPIRequestIdHelper.h"
#import "SPISettlement.h"
#import "SPIWebSocketConnection.h"
#import "SPIPosInfo.h"
#import "SPIDeviceInfo.h"
#import "SPIManifest+Internal.h"
#import "SPIRepeatingTimer.h"
#import "SPIPrinting.h"
#import "SPITerminal.h"
#import "SPIDeviceService.h"
#import "SPITenantsService.h"
#import "SPITerminalHelper.h"


@interface SPIClient () <SPIConnectionDelegate>

// The current status of this SPI instance. Unpaired, PairedConnecting or PairedConnected.
@property (nonatomic, strong) SPIState *state;

@property (nonatomic, strong) id<SPIConnection> connection;

@property (nonatomic, strong) SPIMessageStamp *spiMessageStamp;
@property (nonatomic, strong) SPIPayAtTable *spiPat;
@property (nonatomic, strong) SPIPreAuth *spiPreauth;

@property (nonatomic, strong) SPIRepeatingTimer *pingTimer;
@property (nonatomic, strong) SPIRepeatingTimer *transactionMonitoringTimer;

@property (nonatomic, strong) SPIMessage *mostRecentPingSent;
@property (nonatomic) NSTimeInterval mostRecentPingSentTime;
@property (nonatomic, strong) SPIMessage *mostRecentPongReceived;
@property (nonatomic, assign) NSInteger missedPongsCount;
@property (nonatomic, assign) NSInteger retriesSinceLastDeviceAddressResolution;

@property (nonatomic, strong) SPISignatureRequired *mostRecentSignatureRequiredReceived;

@property (nonatomic, assign) BOOL started;

@property (nonatomic, strong) dispatch_queue_t queue;

@property (nonatomic, strong) NSObject *txLock;

@property (nonatomic, assign) NSInteger retriesSinceLastPairing;

@property (nonatomic, strong) NSRegularExpression *posIdRegex;

@property (nonatomic, strong) NSRegularExpression *eftposAddressRegex;

@property (nonatomic, strong) NSString *libraryLanguage;

@property (nonatomic, strong) NSString *terminalModel;

@end

static NSTimeInterval txMonitorCheckFrequency = 1; // How often do we check on the tx state from our tx monitoring thread

static NSTimeInterval checkOnTxFrequency = 20;  // How often do we proactively check on the tx status by calling get_last_transaction
static NSTimeInterval maxWaitForCancelTx = 10;  // How long do we wait for cancel to return before giving up completely.

static NSTimeInterval pongTimeout = 5; // How long do we wait for a pong to come back
static NSTimeInterval pingFrequency = 18; // How often we send pings
static NSInteger missedPongsToDisconnect = 2; // How many missed pongs before disconnecting
static NSInteger retriesBeforeResolvingDeviceAddress = 3; // How many retries before resolving Device Address

static NSString *regexItemsForPosId = @"^[a-zA-Z0-9]*$";
static NSString *regexItemsForEftposAddress = @"^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}(\\:[0-9]{1,5})?$";

static NSInteger retriesBeforePairing = 3; // How many retries before resolving Device Address

@implementation SPIClient

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _queue = dispatch_queue_create("com.mx51", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0));
        _config = [[SPIConfig alloc] init];
        _state = [SPIState new];
        _posIdRegex = [NSRegularExpression regularExpressionWithPattern:regexItemsForPosId options:NSRegularExpressionCaseInsensitive error:nil];
        _eftposAddressRegex = [NSRegularExpression regularExpressionWithPattern:regexItemsForEftposAddress options:NSRegularExpressionCaseInsensitive error:nil];
        _libraryLanguage = @"ios";
        _txLock = [[NSObject alloc] init];
    }
    
    return self;
}

- (void)dealloc {
    _delegate = nil;
    [_connection disconnect];
    _connection.delegate = nil;
    _connection = nil;
}

- (SPIPreAuth *)enablePreauth {
    _spiPreauth = [[SPIPreAuth alloc] init:self queue:_queue];
    return _spiPreauth;
}

- (SPIPayAtTable *)enablePayAtTable {
    _spiPat = [[SPIPayAtTable alloc] initWithClient:self];
    return _spiPat;
}

#pragma mark - Delegate

- (void)callDelegate:(void (^)(id<SPIDelegate>))block {
    if (self.delegate != nil) {
        __weak __typeof(&*self) weakSelf = self;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            block(weakSelf.delegate);
        });
    }
}

- (void)statusChanged {
    [self callDelegate:^(id<SPIDelegate> delegate) {
        [delegate spi:self statusChanged:self.state.copy];
    }];
}

- (void)pairingFlowStateChanged {
    [self callDelegate:^(id<SPIDelegate> delegate) {
        [delegate spi:self pairingFlowStateChanged:self.state.copy];
    }];
}

- (void)transactionFlowStateChanged {
    [self callDelegate:^(id<SPIDelegate> delegate) {
        [delegate spi:self transactionFlowStateChanged:self.state.copy];
    }];
}

- (void)secretsChanged:(SPISecrets *)secrets {
    [self callDelegate:^(id<SPIDelegate> delegate) {
        [delegate spi:self secretsChanged:secrets state:self.state.copy];
    }];
}

- (void)deviceAddressChanged {
    [self callDelegate:^(id<SPIDelegate> delegate) {
        [delegate spi:self deviceAddressChanged:self.state.copy];
    }];
}

#pragma mark - Setup

- (BOOL)start {
    if (self.started) return false;
    
    NSLog(@"start");
    
    if (self.posVendorId.length == 0 || self.posVersion.length == 0) {
        // POS information is now required to be set
        [NSException raise:@"Missing POS vendor ID and version" format:@"posVendorId and posVersion are required before starting"];
    }
    
    if (![self isPosIdValid:_posId]) {
        // continue, as they can set the posId later on
        _posId = @"";
        NSLog(@"Invalid parameter, please correct them before pairing");
    }
    
    if (![self isEftposAddressValid:_eftposAddress]) {
        // continue, as they can set the eftposAddress later on
        _eftposAddress = @"";
        NSLog(@"Invalid parameter, please correct them before pairing");
    }
    
    // Setup the Connection
    self.connection = [[SPIWebSocketConnection alloc] initWithDelegate:self];
    [self.connection setUrl:self.eftposAddress];
    
    // Set up a weakly repeating timer that avoids memory leaks and automatically invalidates when dereferenced.
    __weak SPIClient* weakSelf = self;
    _transactionMonitoringTimer = [[SPIRepeatingTimer alloc] initWithQueue:"com.mx51.txMonitor"
                                                                  interval:txMonitorCheckFrequency
                                                                     block:^{
        [weakSelf transactionMonitoring];
    }];
    
    self.state.flow = SPIFlowIdle;
    self.started = true;
    
    if (self.secrets && self.eftposAddress) {
        NSLog(@"setup with secrets");
        
        self.state.status = SPIStatusPairedConnecting;
        [self statusChanged];
        [self connect];
        return NO;
    } else {
        NSLog(@"setup with NO secrets");
        
        self.state.status = SPIStatusUnpaired;
        [self statusChanged];
        return YES;
    }
}

+ (NSString *)getVersion {
    return BUNDLE_VERSION_SHORT;
}

- (void)setSecretEncKey:(NSString *)encKey hmacKey:(NSString *)hmacKey {
    self.secrets = [[SPISecrets alloc] initWithEncKey:encKey hmacKey:hmacKey];
}

#pragma mark - Flow management

- (void)ackFlowEndedAndBackToIdle:(SPICompletionState)completion {
    NSLog(@"ackFlowEndedAndBackToIdle");
    
    if (self.state.flow == SPIFlowIdle) {
        completion(YES, self.state.copy); // already idle
        return;
    }
    
    if (self.state.flow == SPIFlowPairing && self.state.pairingFlowState.isFinished) {
        self.state.flow = SPIFlowIdle;
        completion(YES, self.state.copy);
        return;
    }
    if (self.state.flow == SPIFlowTransaction && self.state.txFlowState.isFinished) {
        self.state.flow = SPIFlowIdle;
        completion(YES, self.state.copy);
        return;
    }
    
    completion(NO, self.state.copy);
}

#pragma mark - Pairing

- (void)pair {
    NSLog(@"Trying to pair ....");
    
    if (self.state.status != SPIStatusUnpaired) {
        NSLog(@"Tried to Pair, but we're already paired. Stop pairing.");
        return;
    }
    
    if (![self isPosIdValid:_posId] || ![self isEftposAddressValid:_eftposAddress]) {
        NSLog(@"Invalid Pos Id or Eftpos address, stop pairing.");
        return;
    }
    
    SPIPairingFlowState *currentPairingFlowState = [SPIPairingFlowState new];
    currentPairingFlowState.message = @"Connecting...";
    currentPairingFlowState.confirmationCode = @"";
    currentPairingFlowState.isAwaitingCheckFromEftpos = NO;
    currentPairingFlowState.isAwaitingCheckFromPos = NO;
    
    self.state.flow = SPIFlowPairing;
    self.state.pairingFlowState = currentPairingFlowState;
    
    [self pairingFlowStateChanged];
    
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        [weakSelf.connection connect];
    });
}

- (void)pairingConfirmCode {
    __weak __typeof(&*self) weakSelf = self;
    
    NSLog(@"pairingConfirmCode isAwaitingCheckFromEftpos=%@", @(weakSelf.state.pairingFlowState.isAwaitingCheckFromEftpos));
    
    if (!weakSelf.state.pairingFlowState.isAwaitingCheckFromPos) {
        // We weren't expecting this
        return;
    }
    
    weakSelf.state.pairingFlowState.isAwaitingCheckFromPos = NO;
    
    if (weakSelf.state.pairingFlowState.isAwaitingCheckFromEftpos) {
        // But we are still waiting for confirmation from EFTPOS side.
        weakSelf.state.pairingFlowState.message = [NSString stringWithFormat:@"Click YES on EFTPOS if code is: %@", weakSelf.state.pairingFlowState.confirmationCode];
        [weakSelf pairingFlowStateChanged];
    } else {
        NSLog(@"pairedReady");
        // Already confirmed from EFTPOS - So all good now. We're Paired also
        // from the POS perspective.
        weakSelf.state.pairingFlowState.message = @"Pairing successful";
        [weakSelf onPairingSuccess];
    }
}

- (void)pairingCancel {
    if (_state.flow != SPIFlowPairing || _state.pairingFlowState.isFinished) return;
    
    if (_state.pairingFlowState.isAwaitingCheckFromPos && !_state.pairingFlowState.isAwaitingCheckFromEftpos) {
        [self send:[[[SPIDropKeysRequest alloc] init] toMessage]];
    }
    
    [self onPairingFailed];
}

- (BOOL)unpair {
    if (self.state.status == SPIStatusUnpaired || self.state.flow != SPIFlowIdle) return false;
    
    [self send:[[[SPIDropKeysRequest alloc] init] toMessage]];
    [self doUnpair];
    
    return true;
}

#pragma mark - Transactions

- (void)initiatePurchaseTx:(NSString *)posRefId
               amountCents:(NSInteger)amountCents
                completion:(SPICompletionTxResult)completion {
    
    [self initiatePurchaseTx:posRefId
              purchaseAmount:amountCents
                   tipAmount:0
               cashoutAmount:0
            promptForCashout:NO
                  completion:completion];
}

- (void)initiatePurchaseTx:(NSString *)posRefId
            purchaseAmount:(NSInteger)purchaseAmount
                 tipAmount:(NSInteger)tipAmount
             cashoutAmount:(NSInteger)cashoutAmount
          promptForCashout:(BOOL)promptForCashout
                completion:(SPICompletionTxResult)completion {
    
    [self initiatePurchaseTx:posRefId
              purchaseAmount:purchaseAmount
                   tipAmount:tipAmount
               cashoutAmount:cashoutAmount
            promptForCashout:promptForCashout
                     options:nil
                  completion:completion];
}

- (void)initiatePurchaseTx:(NSString *)posRefId
            purchaseAmount:(NSInteger)purchaseAmount
                 tipAmount:(NSInteger)tipAmount
             cashoutAmount:(NSInteger)cashoutAmount
          promptForCashout:(BOOL)promptForCashout
                   options:(SPITransactionOptions *)options
                completion:(SPICompletionTxResult)completion {
    [self initiatePurchaseTx:posRefId
              purchaseAmount:purchaseAmount
                   tipAmount:tipAmount
               cashoutAmount:cashoutAmount
            promptForCashout:promptForCashout
                     options:nil
             surchargeAmount:0
                  completion:completion];
}

- (void)initiatePurchaseTx:(NSString *)posRefId
            purchaseAmount:(NSInteger)purchaseAmount
                 tipAmount:(NSInteger)tipAmount
             cashoutAmount:(NSInteger)cashoutAmount
          promptForCashout:(BOOL)promptForCashout
                   options:(SPITransactionOptions *)options
           surchargeAmount:(NSInteger)surchargeAmount
                completion:(SPICompletionTxResult)completion {
    
    if (tipAmount > 0 && (cashoutAmount > 0 || promptForCashout)) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Cannot accept tips and cashout at the same time."]);
        return;
    }
    
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    }
    
    // no printing available, reset header and footer and disable print
    if (![SPITerminalHelper isPrinterAvailable:self.terminalModel] && [self isPrintingConfigEnabled]) {
        options = [SPITransactionOptions new];
        self.config.promptForCustomerCopyOnEftpos = NO;
        self.config.printMerchantCopy = NO;
        self.config.signatureFlowOnEftpos = NO;
        SPILog(@"Printing is enabled on a terminal without printer. Printing options will now be disabled.");
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"initPurchase txLock entering");
        @synchronized(weakSelf.txLock) {
            NSLog(@"initPurchase txLock entered");
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPIPurchaseRequest *purchase = [SPIPurchaseHelper createPurchaseRequest:posRefId
                                                                     purchaseAmount:purchaseAmount
                                                                          tipAmount:tipAmount
                                                                         cashAmount:cashoutAmount
                                                                   promptForCashout:promptForCashout
                                                                    surchargeAmount:surchargeAmount];
            purchase.config = weakSelf.config;
            purchase.options = options;
            
            SPIMessage *purchaseMsg = [purchase toMessage];
            
            weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                                 type:SPITransactionTypePurchase
                                                                          amountCents:purchaseAmount
                                                                              message:purchaseMsg
                                                                                  msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to make payment request. %@",
                                                                                       [purchase amountSummary]]];
            
            if ([weakSelf send:purchaseMsg]) {
                [weakSelf.state.txFlowState sent:[NSString stringWithFormat:@"Asked EFTPOS to accept payment for %@", [purchase amountSummary]]];
            }
            NSLog(@"initPurchase txLock exiting");
        }
        
        [self transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Purchase initiated"]);
    });
}

- (void)initiateRefundTx:(NSString *)posRefId
             amountCents:(NSInteger)amountCents
              completion:(SPICompletionTxResult)completion {
    [self initiateRefundTx:posRefId
               amountCents:amountCents
  suppressMerchantPassword:false
                completion:completion];
}

- (void)initiateRefundTx:(NSString *)posRefId
             amountCents:(NSInteger)amountCents
suppressMerchantPassword:(BOOL)suppressMerchantPassword
              completion:(SPICompletionTxResult)completion {
    [self initiateRefundTx:posRefId
               amountCents:amountCents
  suppressMerchantPassword:suppressMerchantPassword
                   options:nil
                completion:completion];
}

- (void)initiateRefundTx:(NSString *)posRefId
             amountCents:(NSInteger)amountCents
suppressMerchantPassword:(BOOL)suppressMerchantPassword
                 options:(SPITransactionOptions *)options
              completion:(SPICompletionTxResult)completion {
    
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    }
    
    
    // no printing available, reset header and footer and disable print
    if (![SPITerminalHelper isPrinterAvailable:self.terminalModel] && [self isPrintingConfigEnabled]) {
        options = [SPITransactionOptions new];
        self.config.promptForCustomerCopyOnEftpos = NO;
        self.config.printMerchantCopy = NO;
        self.config.signatureFlowOnEftpos = NO;
        SPILog(@"Printing is enabled on a terminal without printer. Printing options will now be disabled.");
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        @synchronized(weakSelf.txLock) {
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPIRefundRequest *refund = [[SPIRefundRequest alloc] initWithPosRefId:posRefId
                                                                      amountCents:amountCents];
            refund.suppressMerchantPassword = suppressMerchantPassword;
            refund.config = weakSelf.config;
            refund.options = options;
            
            SPIMessage *refundMsg = [refund toMessage];
            
            weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                                 type:SPITransactionTypeRefund
                                                                          amountCents:amountCents
                                                                              message:refundMsg
                                                                                  msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to make refund request for $%.2f",
                                                                                       amountCents / 100.0]];
            
            if ([weakSelf send:refundMsg]) {
                [weakSelf.state.txFlowState sent:[NSString stringWithFormat:@"Asked EFTPOS to refund $%.2f", amountCents / 100.0]];
            }
        }
        
        [self transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Refund initiated"]);
    });
}

- (void)acceptSignature:(BOOL)accepted {
    NSLog(@"acceptSignature");
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        @synchronized(weakSelf.txLock) {
            if (weakSelf.state.flow != SPIFlowTransaction || weakSelf.state.txFlowState.isFinished || !weakSelf.state.txFlowState.isAwaitingSignatureCheck) {
                SPILog(@"ERROR: Asked to accept signature but I was not waiting for one.");
                return;
            }
            
            [weakSelf.state.txFlowState signatureResponded:accepted ? @"Accepting signature..." : @"Declining signature..."];
            
            NSString *sigReqMsgId = weakSelf.state.txFlowState.signatureRequiredMessage.requestId;
            SPIMessage *msg;
            if (accepted) {
                msg = [[[SPISignatureAccept alloc] initWithSignatureRequiredRequestId:sigReqMsgId] toMessage];
            } else {
                msg = [[[SPISignatureDecline alloc] initWithSignatureRequiredRequestId:sigReqMsgId] toMessage];
            }
            
            [weakSelf send:msg];
        }
        
        [self transactionFlowStateChanged];
    });
}

- (void)initiateCashoutOnlyTx:(NSString *)posRefId
                  amountCents:(NSInteger)amountCents
                   completion:(SPICompletionTxResult)completion {
    [self initiateCashoutOnlyTx:posRefId
                    amountCents:amountCents
                surchargeAmount:0
                     completion:completion];
}

- (void)initiateCashoutOnlyTx:(NSString *)posRefId
                  amountCents:(NSInteger)amountCents
              surchargeAmount:(NSInteger)surchargeAmount
                   completion:(SPICompletionTxResult)completion {
    [self initiateCashoutOnlyTx:posRefId
                    amountCents:amountCents
                surchargeAmount:surchargeAmount
                        options:nil
                     completion:completion];
}

- (void)initiateCashoutOnlyTx:(NSString *)posRefId
                  amountCents:(NSInteger)amountCents
              surchargeAmount:(NSInteger)surchargeAmount
                      options:(SPITransactionOptions *)options
                   completion:(SPICompletionTxResult)completion {
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    }
    
    // no printing available, reset header and footer and disable print
    if (![SPITerminalHelper isPrinterAvailable:self.terminalModel] && [self isPrintingConfigEnabled]) {
        options = [SPITransactionOptions new];
        self.config.promptForCustomerCopyOnEftpos = NO;
        self.config.printMerchantCopy = NO;
        self.config.signatureFlowOnEftpos = NO;
        SPILog(@"Printing is enabled on a terminal without printer. Printing options will now be disabled.");
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        @synchronized(weakSelf.txLock) {
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPICashoutOnlyRequest *cashoutOnlyRequest = [[SPICashoutOnlyRequest alloc] initWithAmountCents:amountCents
                                                                                                  posRefId:posRefId];
            cashoutOnlyRequest.surchargeAmount = surchargeAmount;
            cashoutOnlyRequest.config = weakSelf.config;
            cashoutOnlyRequest.options = options;
            
            SPIMessage *cashoutMsg = [cashoutOnlyRequest toMessage];
            
            self.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                             type:SPITransactionTypeCashoutOnly
                                                                      amountCents:amountCents
                                                                          message:cashoutMsg
                                                                              msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to send cashout request for $%.2f Surcharge: $%.2f", ((float)amountCents / 100.0), ((float)surchargeAmount / 100.0)]];
            
            if ([weakSelf send:cashoutMsg]) {
                [weakSelf.state.txFlowState sent:[NSString stringWithFormat:@"Asked EFTPOS to do cashout for $%.2f Surcharge: $%.2f", ((float)amountCents / 100.0), ((float)surchargeAmount / 100.0)]];
            }
        }
        
        [self transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Cashout initiated"]);
    });
}

- (void)initiateMotoPurchaseTx:(NSString *)posRefId
                   amountCents:(NSInteger)amountCents
                    completion:(SPICompletionTxResult)completion {
    [self initiateMotoPurchaseTx:posRefId
                     amountCents:amountCents
                 surchargeAmount:0
                      completion:completion];
}

- (void)initiateMotoPurchaseTx:(NSString *)posRefId
                   amountCents:(NSInteger)amountCents
               surchargeAmount:(NSInteger)surchargeAmount
                    completion:(SPICompletionTxResult)completion {
    [self initiateMotoPurchaseTx:posRefId
                     amountCents:amountCents
                 surchargeAmount:surchargeAmount
        suppressMerchantPassword:false
                      completion:completion];
}

- (void)initiateMotoPurchaseTx:(NSString *)posRefId
                   amountCents:(NSInteger)amountCents
               surchargeAmount:(NSInteger)surchargeAmount
      suppressMerchantPassword:(BOOL)suppressMerchantPassword
                    completion:(SPICompletionTxResult)completion {
    [self initiateMotoPurchaseTx:posRefId
                     amountCents:amountCents
                 surchargeAmount:surchargeAmount
        suppressMerchantPassword:suppressMerchantPassword
                         options:nil
                      completion:completion];
}

- (void)initiateMotoPurchaseTx:(NSString *)posRefId
                   amountCents:(NSInteger)amountCents
               surchargeAmount:(NSInteger)surchargeAmount
      suppressMerchantPassword:(BOOL)suppressMerchantPassword
                       options:(SPITransactionOptions *)options
                    completion:(SPICompletionTxResult)completion {
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    }
    
    // no printing available, reset header and footer and disable print
    if (![SPITerminalHelper isPrinterAvailable:self.terminalModel] && [self isPrintingConfigEnabled]) {
        options = [SPITransactionOptions new];
        self.config.promptForCustomerCopyOnEftpos = NO;
        self.config.printMerchantCopy = NO;
        self.config.signatureFlowOnEftpos = NO;
        SPILog(@"Printing is enabled on a terminal without printer. Printing options will now be disabled.");
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        @synchronized(weakSelf.txLock) {
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPIMotoPurchaseRequest *motoPurchaseRequest = [[SPIMotoPurchaseRequest alloc] initWithAmountCents:amountCents
                                                                                                     posRefId:posRefId];
            motoPurchaseRequest.surchargeAmount = surchargeAmount;
            motoPurchaseRequest.config = weakSelf.config;
            motoPurchaseRequest.suppressMerchantPassword = suppressMerchantPassword;
            motoPurchaseRequest.options = options;
            
            SPIMessage *cashoutMsg = [motoPurchaseRequest toMessage];
            
            weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                                 type:SPITransactionTypeMOTO
                                                                          amountCents:amountCents
                                                                              message:cashoutMsg
                                                                                  msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to send MOTO request for $%.2f Surcharge: $%.2f", ((float)amountCents / 100), ((float)surchargeAmount / 100.0)]];
            
            if ([weakSelf send:cashoutMsg]) {
                [weakSelf.state.txFlowState sent:[NSString stringWithFormat:@"Asked EFTPOS do MOTO for $%.2f Surcharge: $%.2f", ((float)amountCents / 100), ((float)surchargeAmount / 100.0)]];
            }
        }
        
        [self transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"MOTO initiated"]);
    });
}

- (void)submitAuthCode:(NSString *)authCode completion:(SPIAuthCodeSubmitCompletionResult)completion {
    if (authCode.length != 6) {
        completion([[SPISubmitAuthCodeResult alloc] initWithValidFormat:false msg:@"Not a 6-digit code"]);
        return;
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        @synchronized(weakSelf.txLock) {
            if (weakSelf.state.flow != SPIFlowTransaction || weakSelf.state.txFlowState.isFinished || !weakSelf.state.txFlowState.isAwaitingPhoneForAuth) {
                SPILog(@"ERROR: Asked to send auth code but I was not waiting for one");
                completion([[SPISubmitAuthCodeResult alloc] initWithValidFormat:false msg:@"Was not waiting for one"]);
                return;
            }
            
            [weakSelf.state.txFlowState authCodeSent:[NSString stringWithFormat:@"Submitting auth code %@", authCode]];
            
            SPIMessage *message = [[[SPIAuthCodeAdvice alloc] initWithPosRefId:weakSelf.state.txFlowState.posRefId authCode:authCode] toMessage];
            
            [weakSelf send:message];
        }
        
        [self transactionFlowStateChanged];
        completion([[SPISubmitAuthCodeResult alloc] initWithValidFormat:true msg:@"Valid code"]);
    });
}

- (void)cancelTransaction {
    NSLog(@"cancelTransaction");
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"cancelTx txLock entering");
        @synchronized(weakSelf.txLock) {
            NSLog(@"cancelTx txLock entered");
            
            if (weakSelf.state.flow != SPIFlowTransaction || weakSelf.state.txFlowState.isFinished) {
                SPILog(@"ERROR: Asked to cancel transaction but I was not in the middle of one");
                return;
            }
            
            // TH-1C, TH-3C - Merchant pressed cancel
            if (weakSelf.state.txFlowState.isRequestSent) {
                SPICancelTransactionRequest *cancelReq = [SPICancelTransactionRequest new];
                [weakSelf.state.txFlowState cancelling:@"Attempting to cancel transaction..."];
                [weakSelf send:[cancelReq toMessage]];
            } else {
                // We had not even sent request yet. Consider as known failed.
                [weakSelf.state.txFlowState failed:nil msg:@"Transaction cancelled, request had not even been sent yet"];
            }
            NSLog(@"cancelTx txLock exiting");
        }
        
        [self transactionFlowStateChanged];
        
        [self sendTransactionReport];
        
    });
}

- (void)initiateSettleTx:(NSString *)posRefId
              completion:(SPICompletionTxResult)completion {
    [self initiateSettleTx:posRefId
                   options:nil
                completion:completion];
}

- (void)initiateSettleTx:(NSString *)posRefId
                 options:(SPITransactionOptions *)options
              completion:(SPICompletionTxResult)completion {
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    }
    
    
    // no printing available, reset header and footer and disable print
    if (![SPITerminalHelper isPrinterAvailable:self.terminalModel] && [self isPrintingConfigEnabled]) {
        options = [SPITransactionOptions new];
        self.config.promptForCustomerCopyOnEftpos = NO;
        self.config.printMerchantCopy = NO;
        self.config.signatureFlowOnEftpos = NO;
        SPILog(@"Printing is enabled on a terminal without printer. Printing options will now be disabled.");
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        @synchronized(weakSelf.txLock) {
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPISettleRequest *settleRequest = [[SPISettleRequest alloc] initWithSettleId:[SPIRequestIdHelper idForString:@"settle"]];
            settleRequest.config = weakSelf.config;
            settleRequest.options = options;
            
            SPIMessage *settleMessage = [settleRequest toMessage];
            
            weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                                 type:SPITransactionTypeSettle
                                                                          amountCents:0
                                                                              message:settleMessage
                                                                                  msg:@"Waiting for EFTPOS connection to make a settle request"];
            
            if ([weakSelf send:settleMessage]) {
                [weakSelf.state.txFlowState sent:@"Asked EFTPOS to settle"];
            }
        }
        
        [self transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Settle initiated"]);
    });
}

- (void)initiateSettlementEnquiry:(NSString *)posRefId
                       completion:(SPICompletionTxResult)completion {
    [self initiateSettlementEnquiry:posRefId
                            options:nil
                         completion:completion];
}

- (void)initiateSettlementEnquiry:(NSString *)posRefId
                          options:(SPITransactionOptions *)options
                       completion:(SPICompletionTxResult)completion {
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        @synchronized(weakSelf.txLock) {
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPISettlementEnquiryRequest *settleEnqRequest = [[SPISettlementEnquiryRequest alloc] initWithRequestId:[SPIRequestIdHelper idForString:@"stlenq"]];
            settleEnqRequest.config = weakSelf.config;
            settleEnqRequest.options = options;
            
            SPIMessage *stlEnqMsg = [settleEnqRequest toMessage];
            
            weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                                 type:SPITransactionTypeSettleEnquiry
                                                                          amountCents:0
                                                                              message:stlEnqMsg
                                                                                  msg:@"Waiting for EFTPOS connection to make a settlement enquiry"];
            
            if ([weakSelf send:stlEnqMsg]) {
                [weakSelf.state.txFlowState sent:@"Asked EFTPOS to make a settlement enquiry"];
            }
        }
        
        [weakSelf transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Settle Initiated"]);
    });
}

- (void)initiateGetTxWithPosRefID:(NSString *)posRefId
                       completion:(SPICompletionTxResult)completion {
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"initGt txLock entering");
        @synchronized(weakSelf.txLock) {
            NSLog(@"initGt txLock entered");
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPIGetTransactionRequest *gtRequest = [[SPIGetTransactionRequest alloc] initWithPosRefId:posRefId];
            
            SPIMessage *gtMessage = [gtRequest toMessage];
            
            weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                                 type:SPITransactionTypeGetTransaction
                                                                          amountCents:0
                                                                              message:gtMessage
                                                                                  msg:@"Waiting for EFTPOS connection to make a get transaction request"];
            
            [weakSelf.state.txFlowState callingGt:gtMessage.mid];
            
            if ([weakSelf send:gtMessage]) {
                [weakSelf.state.txFlowState sent:[NSString stringWithFormat:@"Asked EFTPOS to get transaction: %@", posRefId]];
            }
            NSLog(@"initGt txLock exiting");
        }
        
        [weakSelf transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Get transaction initiated"]);
    });
}


- (void)initiateGetLastTxWithCompletion:(SPICompletionTxResult)completion {
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"initGlt txLock entering");
        @synchronized(weakSelf.txLock) {
            NSLog(@"initGlt txLock entered");
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPIGetLastTransactionRequest *gltRequest = [SPIGetLastTransactionRequest new];
            
            SPIMessage *gltMessage = [gltRequest toMessage];
            
            weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:gltMessage.mid
                                                                                 type:SPITransactionTypeGetLastTransaction
                                                                          amountCents:0
                                                                              message:gltMessage
                                                                                  msg:@"Waiting for EFTPOS connection to make a get last transaction request"];
            
            if ([weakSelf send:gltMessage]) {
                [weakSelf.state.txFlowState sent:@"Asked EFTPOS to get last transaction"];
            }
            NSLog(@"initGlt txLock exiting");
        }
        
        [weakSelf transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Get last transaction initiated"]);
    });
}

- (void)initiateRecovery:(NSString *)posRefId
         transactionType:(SPITransactionType)txType
              completion:(SPICompletionTxResult)completion {
    
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:false message:@"Not paired"]);
        return;
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"initRecov txLock entering");
        @synchronized(weakSelf.txLock) {
            NSLog(@"initRecov txLock entered");
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:false message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPIGetTransactionRequest *gtRequest = [[SPIGetTransactionRequest alloc] initWithPosRefId:posRefId];
            
            SPIMessage *gtRequestMsg = [gtRequest toMessage];
            
            weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                                 type:txType
                                                                          amountCents:0
                                                                              message:gtRequestMsg
                                                                                  msg:@"Waiting for EFTPOS connection to attempt recovery"];
            [weakSelf.state.txFlowState callingGt:gtRequestMsg.mid];
            if ([weakSelf send:gtRequestMsg]) {
                [weakSelf.state.txFlowState sent:@"Asked EFTPOS to recover state"];
            }
            NSLog(@"initRecov txLock exiting");
        }
        
        [weakSelf transactionFlowStateChanged];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Recovery initiated"]);
    });
}

- (void)initiateReversal:(NSString *)posRefId
              completion:(SPICompletionTxResult)completion {
    
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:false message:@"Not paired"]);
        return;
    }
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"initReversal txLock entering");
        @synchronized(weakSelf.txLock) {
            NSLog(@"initReversal txLock entered");
            if (weakSelf.state.flow != SPIFlowIdle) {
                completion([[SPIInitiateTxResult alloc] initWithTxResult:false message:@"Not idle"]);
                return;
            }
            
            weakSelf.state.flow = SPIFlowTransaction;
            
            SPIReversalRequest *revRequest = [[SPIReversalRequest alloc] initWithPosRefId:posRefId];
            
            SPIMessage *revRequestMsg = [revRequest toMessage];
            
            weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:posRefId
                                                                                 type:SPITransactionTypeReversal
                                                                          amountCents:0
                                                                              message:revRequestMsg
                                                                                  msg:@"Waiting for EFTPOS connection to attempt reversal"];
            
            if ([weakSelf send:revRequestMsg]) {
                [weakSelf.state.txFlowState sent:@"Asked EFTPOS for reversal"];
            }
            NSLog(@"initReversal txLock exiting");
        }
        
        [weakSelf transactionFlowStateChanged];
        [self sendTransactionReport];
        
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Reversal initiated"]);
    });
}

- (void)printReport:(NSString *)key
            payload:(NSString *)payload {
    [self send:[[[SPIPrintingRequest alloc] initWithKey:key payload:payload] toMessage]];
}

- (void)getTerminalStatus {
    [self send:[[[SPITerminalStatusRequest alloc] init] toMessage]];
}

- (void)getTerminalConfiguration {
    [self send:[[[SPITerminalConfigurationRequest alloc] init] toMessage]];
}

#pragma mark -
#pragma mark - Connection

- (void)setEftposAddress:(NSString *)url {
    if (self.state.status == SPIStatusPairedConnected || _autoAddressResolutionEnable) {
        return;
    }
    
    _eftposAddress = @"";
    
    if (![self isEftposAddressValid:url.copy]) {
        NSLog(@"Eftpos Address set to null");
        return;
    }
    
    if (![url hasPrefix:@"ws://"]) {
        url = [NSString stringWithFormat:@"ws://%@", url];
    }
    
    _eftposAddress = [url copy];
    NSLog(@"setUrl: %@", _eftposAddress);
    
    [self.connection setUrl:url.copy];
}

- (void)setPosId:(NSString *)posId {
    if (self.state.status != SPIStatusUnpaired) {
        return;
    }
    
    _posId = @"";
    
    if (![self isPosIdValid:posId.copy]) {
        NSLog(@"Pos Id set to null");
        return;
    }
    
    _posId = posId;
    
    NSLog(@"setPosId: %@ and set spiMessageStamp", posId);
    
    if (_posId.length > 0) {
        // Our stamp for signing outgoing messages
        self.spiMessageStamp = [[SPIMessageStamp alloc] initWithPosId:posId secrets:nil];
    }
}

/**
 * Events the are triggered:
 * SPIKeyRequestKey
 * SPIKeyCheckKey
 */
- (void)connect {
    SPILog(@"Connecting: %@, %@", self.posId, self.eftposAddress);
    
    if (!self.secrets) {
        SPILog(@"Select the \"Pair with POS\" option on the EFTPOS terminal screen. Once selected, the EFTPOS terminal screen should read \"Start POS Pairing\"");
    }
    
    // Actually do connection.
    // This is non-blocking
    [self.connection connect];
}

- (void)disconnect {
    SPILog(@"Disconnecting");
    [self.connection disconnect];
}

- (BOOL)send:(SPIMessage *)message {
    NSString *json = [message toJson:self.spiMessageStamp];
    
    if (self.connection.isConnected) {
        SPILog(@"Sending message: %@", message.decryptedJson);
        [self.connection send:json];
        return YES;
    } else {
        SPILog(@"ERROR: Asked to send, but not connected: %@", message.decryptedJson);
        return NO;
    }
}

#pragma mark - Device Management

/**
 Set the acquirer code of your bank, please contact mx51's Integration Engineers for acquirer code.
 */
- (void)setAcquirerCode:(NSString *)acquirerCode {
    _acquirerCode = acquirerCode.copy;
}

/**
 Set the api key used for auto address discovery feature, please contact mx51's Integration Engineers for Api key.
 */
- (void)setDeviceApiKey:(NSString *)deviceApiKey {
    _deviceApiKey = deviceApiKey.copy;
}

/**
 Allows you to set the serial number of the Eftpos
 */
- (void)setSerialNumber:(NSString *)serialNumber {
    if (self.state.status != SPIStatusUnpaired) {
        return;
    }
    
    NSString *was = _serialNumber;
    _serialNumber = serialNumber.copy;
    
    if ([self hasSerialNumberChanged:was]) {
        __weak __typeof(&*self) weakSelf = self;
        
        dispatch_async(self.queue, ^{
            // we're turning it on
            [weakSelf autoResolveEftposAddress];
        });
    } else {
        if (self.state.deviceAddressStatus == nil) {
            self.state.deviceAddressStatus = [[SPIDeviceAddressStatus alloc] init];
        }
        
        self.state.deviceAddressStatus.deviceAddressResponseCode = DeviceAddressResponseCodeSerialNumberNotChanged;
        [self deviceAddressChanged];
    }
}

/**
 Allows you to set the auto address discovery feature.
 */
- (void)setAutoAddressResolutionEnable:(BOOL)autoAddressResolutionEnable {
    if (self.state.status == SPIStatusPairedConnected) {
        return;
    }
    
    BOOL was = _autoAddressResolutionEnable;
    _autoAddressResolutionEnable = autoAddressResolutionEnable;
    
    if (_autoAddressResolutionEnable && !was) {
        __weak __typeof(&*self) weakSelf = self;
        
        dispatch_async(self.queue, ^{
            // we're turning it on
            [weakSelf autoResolveEftposAddress];
        });
    }
}

/**
 Allows you to set the auto address discovery feature.
 */
- (void)setTestMode:(BOOL)testMode {
    if (self.state.status != SPIStatusUnpaired) {
        return;
    }
    
    if (testMode == _testMode) {
        return;
    }
    
    // we're changing mode
    _testMode = testMode;
    
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        // we're turning it on
        [weakSelf autoResolveEftposAddress];
    });
}

- (BOOL)hasSerialNumberChanged:(NSString *)updatedSerialNumber {
    if ([_serialNumber isEqualToString:updatedSerialNumber]) {
        return false;
    }
    
    return true;
}

- (BOOL)hasEftposAddressChanged:(NSString *)updatedEftposAddress {
    if ([_eftposAddress isEqualToString:updatedEftposAddress]) {
        return false;
    }
    
    return true;
}

- (void)autoResolveEftposAddress {
    if (!_autoAddressResolutionEnable) {
        return;
    }
    
    if (_serialNumber.length == 0) {
        return;
    }
    
    [[SPIDeviceService alloc] retrieveServiceWithSerialNumber:_serialNumber apiKey:_deviceApiKey acquirerCode:_acquirerCode isTestMode:_testMode completion:^(SPIDeviceAddressStatus *addressResponse) {
        
        SPIDeviceAddressStatus *currentDeviceAddressStatus = [SPIDeviceAddressStatus new];
        
        if (addressResponse == nil) {
            currentDeviceAddressStatus.deviceAddressResponseCode = DeviceAddressResponseCodeDeviceError;
            self.state.deviceAddressStatus = currentDeviceAddressStatus;
            [self deviceAddressChanged];
            return;
        }
        
        if (addressResponse.address.length == 0) {
            if (addressResponse.responseCode == 404) {
                currentDeviceAddressStatus.deviceAddressResponseCode = DeviceAddressResponseCodeInvalidSerialNumber;
                self.state.deviceAddressStatus = currentDeviceAddressStatus;
                [self deviceAddressChanged];
                return;
            } else {
                currentDeviceAddressStatus.deviceAddressResponseCode = DeviceAddressResponseCodeDeviceError;
                self.state.deviceAddressStatus = currentDeviceAddressStatus;
                [self deviceAddressChanged];
                return;
            }
        }
        
        if (![self hasEftposAddressChanged:addressResponse.address]) {
            currentDeviceAddressStatus.deviceAddressResponseCode = DeviceAddressResponseCodeAddressNotChanged;
            self.state.deviceAddressStatus = currentDeviceAddressStatus;
            [self deviceAddressChanged];
            return;
        }
        
        // update device and connection address
        self->_eftposAddress = [NSString stringWithFormat:@"ws://%@", addressResponse.address];
        [self->_connection setUrl:self->_eftposAddress];
        
        currentDeviceAddressStatus.address = addressResponse.address;
        currentDeviceAddressStatus.lastUpdated = addressResponse.lastUpdated;
        currentDeviceAddressStatus.deviceAddressResponseCode = DeviceAddressResponseCodeSuccess;
        self.state.deviceAddressStatus = currentDeviceAddressStatus;
        [self deviceAddressChanged];
    }];
}

#pragma Static Methods

+ (void)getAvailableTenants:(NSString *)posVendorId
                     apiKey:(NSString *)apiKey
                countryCode:(NSString *)countryCode
                 completion:(SPITenantsResult)completion {
    
    [[SPITenantsService alloc] retrieveTenants:posVendorId apiKey:apiKey countryCode:countryCode completion: ^(NSArray *tenants) {
        completion(tenants);
        return;
    }];
}

#pragma mark - Events

/**
 * Handling the 2nd interaction of the pairing process, i.e. an incoming
 * KeyRequest.
 *
 * @param m Message
 */
- (void)handleKeyRequest:(SPIMessage *)m {
    NSLog(@"handleKeyRequest");
    
    self.state.pairingFlowState.message = @"Negotiating pairing...";
    [self pairingFlowStateChanged];
    
    // Use the helper. It takes the incoming request, and generates the secrets
    // and the response.
    SPISecretsAndKeyResponse *result = [SPIPairingHelper generateSecretsAndKeyResponseForKeyRequest:[[SPIKeyRequest alloc] initWithMessage:m]];
    self.secrets = result.secrets; // we now have secrets, although pairing is not fully finished yet.
    self.spiMessageStamp.secrets = self.secrets; // updating our stamp with the secrets so can encrypt messages later.
    [self send:[result.keyResponse toMessage]]; // send the key_response, i.e. interaction 3 of pairing.
}

/**
 *
 * Handling the 4th interaction of the pairing process i.e. an incoming
 * KeyCheck.
 * This method is just showing code since auto confirmation is implemented (SP-297)
 * @param m Message
 */
- (void)handleKeyCheck:(SPIMessage *)m {
    NSLog(@"handleKeyCheck");
    
    SPIKeyCheck *keyCheck = [[SPIKeyCheck alloc] initWithMessage:m];
    self.state.pairingFlowState.message = [NSString stringWithFormat:@"Confirmation code:\n%@",
                                           keyCheck.confirmationCode];
    [self pairingFlowStateChanged];
}

/**
 * Handling the 5th and final interaction of the pairing process, i.e. an
 * incoming PairResponse
 *
 * @param m Message
 */
- (void)handlePairResponse:(SPIMessage *)m {
    NSLog(@"handlePairResponse");
    
    SPIPairResponse *pairResponse = [[SPIPairResponse alloc] initWithMessage:m];
    self.state.pairingFlowState.isAwaitingCheckFromEftpos = NO;
    
    if (pairResponse.isSuccess) {
        if (self.state.pairingFlowState.isAwaitingCheckFromPos) {
            // Waiting for PoS, auto confirming code
            SPILog(@"Confirming pairing from library.");
            [self pairingConfirmCode];
        }
        SPILog(@"Got Pair Confirm from Eftpos, and already had confirm from POS. Now just waiting for first pong.");
        [self onPairingSuccess];
        // I need to ping/login even if the pos user has not said yes yet,
        // because otherwise within 5 seconds connectiong will be dropped by
        // EFTPOS.
        [self startPeriodicPing];
    } else {
        [self onPairingFailed];
    }
}

- (void)handleDropKeysAdvice:(SPIMessage *)message {
    SPILog(@"EFTPOS was unpaired. I shall unpair from my end as well.");
    [self doUnpair];
}

- (void)doUnpair {
    _state.status = SPIStatusUnpaired;
    [self statusChanged];
    [_connection disconnect];
    _secrets = nil;
    _spiMessageStamp.secrets = nil;
    [self secretsChanged:_secrets];
}

- (void)onPairingSuccess {
    NSLog(@"onPairingSuccess");
    
    self.state.pairingFlowState.isSuccessful = YES;
    self.state.pairingFlowState.isFinished = YES;
    self.state.pairingFlowState.message = @"Pairing successful!";
    self.state.status = SPIStatusPairedConnected;
    [self secretsChanged:self.secrets];
    [self pairingFlowStateChanged];
}

- (void)onPairingFailed {
    NSLog(@"onPairingFailed");
    
    self.secrets = nil;
    self.spiMessageStamp.secrets = nil;
    [self.connection disconnect];
    
    self.state.status = SPIStatusUnpaired;
    [self statusChanged];
    
    self.state.pairingFlowState.message = @"Pairing failed";
    self.state.pairingFlowState.isFinished = YES;
    self.state.pairingFlowState.isSuccessful = NO;
    self.state.pairingFlowState.isAwaitingCheckFromPos = NO;
    [self pairingFlowStateChanged];
}

/**
 * Sometimes the server asks us to roll our secrets.
 *
 * @param m Message
 */
- (void)handleKeyRollingRequest:(SPIMessage *)m {
    NSLog(@"handleKeyRollingRequest");
    // we calculate the new ones...
    SPIKeyRollingResult *krRes = [SPIKeyRollingHelper performKeyRollingWithMessage:m currentSecrets:self.secrets];
    self.secrets = krRes.secrets;                // and update our secrets with them
    self.spiMessageStamp.secrets = self.secrets; // and our stamp
    [self send:krRes.keyRollingConfirmation];
    [self secretsChanged:self.secrets];
    
    self.mostRecentPingSent = nil;
    [self startPeriodicPing];
}

#pragma mark - Transaction Management

/**
 * The PIN pad server will send us this message when a customer signature is
 * reqired. We need to ask the customer to sign the incoming receipt. And then
 * tell the pinpad whether the signature is ok or not.
 *
 * @param m Message
 */
- (void)handleSignatureRequired:(SPIMessage *)m {
    NSLog(@"handleSignatureRequired");
    
    @synchronized(self.txLock) {
        NSString *incomingPosRefId = [m getDataStringValue:@"pos_ref_id"];
        if (self.state.flow != SPIFlowTransaction || self.state.txFlowState.isFinished || ![self.state.txFlowState.posRefId isEqualToString:incomingPosRefId]) {
            SPILog(@"ERROR: Received signature required but I was not waiting for one. %@", m.decryptedJson);
            return;
        }
        
        [self.state.txFlowState signatureRequired:[[SPISignatureRequired alloc] initWithMessage:m] msg:@"Ask customer to sign the receipt"];
    }
    
    [self transactionFlowStateChanged];
}

- (void)handleAuthCodeRequired:(SPIMessage *)m {
    NSLog(@"handleAuthCodeRequired");
    
    @synchronized(self.txLock) {
        NSString *incomingPosRefId = [m getDataStringValue:@"pos_ref_id"];
        if (self.state.flow != SPIFlowTransaction || self.state.txFlowState.isFinished || ![self.state.txFlowState.posRefId isEqualToString:incomingPosRefId]) {
            SPILog(@"ERROR: Received auth code required but I was not waiting for one. Incoming POS ref ID: %@", incomingPosRefId);
            return;
        }
        
        SPIPhoneForAuthRequired *phoneForAuthRequired = [[SPIPhoneForAuthRequired alloc] initWithMessage:m];
        NSString *msg = [NSString stringWithFormat:@"Auth code required. Call %@ and quote merchant ID %@",
                         phoneForAuthRequired.getPhoneNumber, phoneForAuthRequired.getMerchantId];
        
        [self.state.txFlowState phoneForAuthRequired:phoneForAuthRequired msg:msg];
    }
    
    [self transactionFlowStateChanged];
}

/**
 * The PIN pad server will reply to our purchase request with a purchase response.
 *
 * @param m Message
 */
- (void)handlePurchaseResponse:(SPIMessage *)m {
    [self handleTxResponse:m type:SPITransactionTypePurchase checkPosRefId:YES];
}

/**
 * The PIN pad server will reply to our cashout only request with a cashout only response.
 *
 * @param m Message
 */
- (void)handleCashoutOnlyResponse:(SPIMessage *)m {
    [self handleTxResponse:m type:SPITransactionTypeCashoutOnly checkPosRefId:YES];
}

/**
 * The PIN pad server will reply to our MOTO purchase request with a MOTO purchase response.
 *
 * @param m Message
 */
- (void)handleMotoPurchaseResponse:(SPIMessage *)m {
    [self handleTxResponse:m type:SPITransactionTypeMOTO checkPosRefId:YES];
}

/**
 * The PIN pad server will reply to our refund request with a refund response.
 *
 * @param m Message
 */
- (void)handleRefundResponse:(SPIMessage *)m {
    [self handleTxResponse:m type:SPITransactionTypeRefund checkPosRefId:YES];
}

- (void)handleReversalResponse:(SPIMessage *)m {
    
    NSLog(@"handleReversalResponse");
    NSLog(@"handleReversalResp txLock entering");
    @synchronized(self.txLock) {
        NSLog(@"handleReversalResp txLock entered");
        SPITransactionFlowState *txState = self.state.txFlowState;
        NSDictionary *dict = m.data;
        NSString *incomingPosRefId = [dict objectForKey:@"pos_ref_id"];
        
        SPIReversalResponse *revResp = [[SPIReversalResponse alloc] initWithMessage:m];
        
        if (self.state.flow != SPIFlowTransaction || txState.isFinished || txState.posRefId == incomingPosRefId) {
            SPILog(@"Received Reversal response but I was not waiting for this one. Incoming Pos Ref ID: %@", incomingPosRefId);
            return;
        }
        
        if (!revResp.isSuccess) {
            [txState completed:m.successState response:m msg:revResp.getErrorDetail];
        } else {
            [txState completed:m.successState response:m msg:@"Reversal completed"];
        }
    }
    NSLog(@"handleReversalResp txLock exiting");
    
    
    [self transactionFlowStateChanged];
    
    [self sendTransactionReport];
}


/**
 * Handle the settlement response received from the PIN pad.
 *
 * @param m Message
 */
- (void)handleSettleResponse:(SPIMessage *)m {
    [self handleTxResponse:m type:SPITransactionTypeSettle checkPosRefId:NO];
}

/**
 * Handle the settlement request received from the PIN pad.
 *
 * @param m Message
 */
- (void)handleSettlementEnquiryResponse:(SPIMessage *)m {
    [self handleTxResponse:m type:SPITransactionTypeSettleEnquiry checkPosRefId:NO];
}

- (void)handleTxResponse:(SPIMessage *)m
                    type:(SPITransactionType)type
           checkPosRefId:(BOOL)checkPosRefId {
    
    NSLog(@"handleTxResp txLock entering");
    @synchronized(self.txLock) {
        NSLog(@"handleTxResp txLock entered");
        NSString *typeName = [SPITransactionFlowState txTypeString:type];
        
        if ([self isTxResponseUnexpected:m typeName:typeName checkPosRefId:checkPosRefId]) return;
        
        NSString *msg = [typeName stringByAppendingString:@" transaction ended"];
        [self.state.txFlowState completed:m.successState response:m msg:msg];
        // TH-6A, TH-6E
        
        NSLog(@"handleTxResp txLock exiting");
    }
    
    [self transactionFlowStateChanged];
    
    [self sendTransactionReport];
}

/**
 * Verifies transaction response (TH-1A, TH-2A).
 *
 * @return YES if transaction response is unexpected and should be ignored, false if all is well.
 */
- (BOOL)isTxResponseUnexpected:(SPIMessage *)m
                      typeName:(NSString *)typeName
                 checkPosRefId:(BOOL)checkPosRefId {
    
    SPITransactionFlowState *txState = self.state.txFlowState;
    
    NSString *incomingPosRefId;
    BOOL posRefIdMatched;
    if (checkPosRefId) {
        incomingPosRefId = [m getDataStringValue:@"pos_ref_id"];
        posRefIdMatched = [txState.posRefId isEqualToString:incomingPosRefId];
    } else {
        incomingPosRefId = nil;
        posRefIdMatched = YES;
    }
    
    if (self.state.flow != SPIFlowTransaction || txState.isFinished || !posRefIdMatched) {
        NSString *trace = checkPosRefId ? [@"Incoming Pos Ref ID: " stringByAppendingString:incomingPosRefId] : m.decryptedJson;
        if ([typeName  isEqual: @"Cancel"]) {
            SPICancelTransactionResponse *response = [[SPICancelTransactionResponse alloc] initWithMessage:m];
            if (!response.wasTxnPastPointOfNoReturn) {
                SPILog(@"ERROR: Received %@ response but I was not waiting for one. %@", typeName, trace);
                return YES;
            }
        } else {
            SPILog(@"ERROR: Received %@ response but I was not waiting for one. %@", typeName, trace);
            return YES;
        }
    }
    return NO;
}

/**
 * Sometimes we receive event type "error" from the server, such as when calling
 * cancel_transaction and there is no transaction in progress.
 *
 * @param m SPIMessage
 */
- (void)handleErrorEvent:(SPIMessage *)m {
    NSLog(@"handleError txLock entering");
    @synchronized(self.txLock) {
        NSLog(@"handleError txLock entered");
        if (self.state.flow == SPIFlowTransaction && !self.state.txFlowState.isFinished &&
            self.state.txFlowState.isAttemptingToCancel && [m.error isEqualToString:@"NO_TRANSACTION"]) {
            // TH-2E
            SPILog(@"Was trying to cancel a transaction but there is nothing to cancel. Calling GT to see what's up");
            
            __weak __typeof(& *self) weakSelf = self;
            
            dispatch_async(self.queue, ^{
                [weakSelf callGetTransaction:weakSelf.state.txFlowState.posRefId];
            });
        } else {
            SPILog(@"Received error event but don't know what to do with it. %@", m.decryptedJson);
        }
        NSLog(@"handleError txLock exiting");
    }
}


- (void)handleGetTransactionResponse:(SPIMessage *)m {
    NSLog(@"handleGetTransactionResponse");
    NSLog(@"handleGtResp txLock entering");
    @synchronized(self.txLock) {
        NSLog(@"handleGtResp txLock entered");
        SPITransactionFlowState *txState = self.state.txFlowState;
        
        if (self.state.flow != SPIFlowTransaction || txState.isFinished) {
            SPILog(@"Received gt response but we were not in the middle of a tx. ignoring.");
            return;
        }
        
        if (!txState.isAwaitingGtResponse) {
            SPILog(@"received a gt response but we had not asked for one within this transaction. Perhaps leftover from previous one. ignoring.");
            return;
        }
        
        if (txState.gtRequestId != m.mid) {
            SPILog(@"received a gt response but the message id does not match the gt request that we sent. strange. ignoring.");
            return;
        }
        
        SPILog(@"Got transaction. Attempting recovery.");
        [txState gotGtResponse];
        
        SPIGetTransactionResponse *gtResponse = [[SPIGetTransactionResponse alloc] initWithMessage:m];
        
        if (!gtResponse.wasRetrievedSuccessfully) {
            // GetTransaction Failed... let's figure out one of reason and act accordingly
            if ([gtResponse isWaitingForSignatureResponse]) {
                
                if (!txState.isAwaitingSignatureCheck) {
                    SPILog(@"GTR-01: Eftpos is waiting for us to send it signature accept/decline, but we were not aware of this. The user can only really decline at this stage as there is no receipt to print for signing.");
                    
                    SPISignatureRequired *req = [[SPISignatureRequired alloc] initWithPosRefId:txState.posRefId
                                                                                     requestId:m.mid
                                                                                 receiptToSign:@"MISSING RECEIPT\n DECLINE AND TRY AGAIN."];
                    [self.state.txFlowState signatureRequired:req msg:@"Recovered in signature required but we don't have receipt. You may decline then retry."];
                } else {
                    SPILog(@"Waiting for Signature response ... stay waiting.");
                    // No need to publish txFlowStateChanged. Can return;
                    return;
                }
            } else if ([gtResponse isWaitingForAuthCode] && ![txState isAwaitingPhoneForAuth]) {
                SPILog(@"GTR-02: Eftpos is waiting for us to send it auth code, but we were not aware of this. We can only cancel the transaction at this stage as we don't have enough information to recover from this.");
                [txState phoneForAuthRequired:[[SPIPhoneForAuthRequired alloc] initWithPosRefId:txState.posRefId requestId:m.mid phoneNumber:@"UNKNOWN" merchantId:@"UNKNOWN"] msg:@"Recovered mid Phone-For-Auth but don't have details. You may Cancel then Retry."];
            } else if ([gtResponse wasTransactionInProgressError]) {
                SPILog(@"GTR-03: Transaction is currently in progress... stay waiting.");
                return;
            } else if ([gtResponse wasRefIDNotFoundError]) {
                SPILog(@"GTR-04: Get transaction failed, PosRefId is not found.");
                [txState completed:SPIMessageSuccessStateFailed response:m msg:[NSString stringWithFormat:@"PosRefId not found for %@", txState.posRefId]];
            } else if ([gtResponse isInvalidArgumentsError]) {
                SPILog(@"GTR-05: Get transaction failed, PosRefId is invalid.");
                [txState completed:SPIMessageSuccessStateFailed response:m msg:[NSString stringWithFormat:@"PosRefId invalid for %@", txState.posRefId]];
            } else if ([gtResponse isMissingArgumentsError]) {
                SPILog(@"GTR-06: Get transaction failed, PosRefId is missing.");
                [txState completed:SPIMessageSuccessStateFailed response:m msg:[NSString stringWithFormat:@"PosRefId is missing for %@", txState.posRefId]];
            } else if ([gtResponse isSomethingElseBlocking]) {
                SPILog(@"GTR-07: Terminal is Blocked by something else... stay waiting.");
                return;
            } else {
                // get transaction failed, but we weren't given a specific reason
                SPILog(@"GTR-08: Unexpected Response in Get Transaction - Received posRefId:%@ Error:%@", txState.posRefId, m.error);
                [txState completed:SPIMessageSuccessStateFailed response:m msg:[NSString stringWithFormat:@"Get Transaction failed, %@", m.error]];
            }
        } else {
            SPIMessage *tx = [gtResponse getTxMessage];
            if (tx == nil) {
                // tx payload missing from get transaction protocol, could be a VAA issue.
                SPILog(@"GTR-09: Unexpected Response in Get Transaction. Missing TX payload... stay waiting");
                return;
            }
            
            // get transaction was successful
            [gtResponse copyMerchantReceiptToCustomerReceipt];
            if (txState.type == SPITransactionTypeGetTransaction) {
                // this was a get transaction request, not for recovery
                SPILog(@"GTR-10: Retrieved Transaction as asked directly by the user.");
                [txState completed:tx.successState response:tx msg:[NSString stringWithFormat:@"Transaction Retrieved for %@", [gtResponse getPosRefId]]];
            } else {
                // this was a get transaction from a recovery
                SPILog(@"GTR-11: Retrieved transaction during recovery.");
                [txState completed:tx.successState response:tx msg:[NSString stringWithFormat:@"Transaction Recovered for %@", [gtResponse getPosRefId]]];
            }
        }
    }
    NSLog(@"handleGltResp txLock exiting");
    [self transactionFlowStateChanged];
    
    [self sendTransactionReport];
}


/**
 * When the PIN pad returns to us what the last transaction was.
 *
 * @param m Message
 */
- (void)handleGetLastTransactionResponse:(SPIMessage *)m {
    NSLog(@"handleGetLastTransactionResponse");
    NSLog(@"handleGltResp txLock entering");
    @synchronized(self.txLock) {
        NSLog(@"handleGltResp txLock entered");
        SPITransactionFlowState *txState = self.state.txFlowState;
        
        if (self.state.flow != SPIFlowTransaction || txState.isFinished || txState.type != SPITransactionTypeGetLastTransaction) {
            SPILog(@"Received glt response but we were not expecting one. ignoring.");
            return;
        }
        
        SPILog(@"Got Last Transaction Response.");
        
        SPIGetLastTransactionResponse *gltResponse = [[SPIGetLastTransactionResponse alloc] initWithMessage:m];
        
        if (!gltResponse.wasRetrievedSuccessfully) {
            SPILog(@"Error in Response for Get Last Transaction - Received posRefId:%@ Error:%@. UnknownCompleted.", [gltResponse getPosRefId], [m error]);
            [txState unknownCompleted:@"Failed to Retrieve Last Transaction"];
        } else {
            SPILog(@"Retrieved Last Transaction as asked directly by the user.");
            [gltResponse copyMerchantReceiptToCustomerReceipt];
            [txState completed:[gltResponse getSuccessState] response:m msg:@"Last transaction retrieved"];
        }
    }
    
    [self transactionFlowStateChanged];
}

/**
 * When the transaction cancel response is returned.
 *
 * @param m Message
 */
- (void)handleCancelTransactionResponse:(SPIMessage *)m {
    NSLog(@"handleCancelTxResp txLock entering");
    @synchronized(self.txLock) {
        NSLog(@"handleCancelTxResp txLock entered");
        if ([self isTxResponseUnexpected:m typeName:@"Cancel" checkPosRefId:YES]) return;
        
        SPICancelTransactionResponse *response = [[SPICancelTransactionResponse alloc] initWithMessage:m];
        if (response.isSuccess) {
            // We can ignore successful cancellation, we will just get purchase response shortly
            return;
        }
        
        SPILog(@"ERROR: Failed to cancel transaction: reason=%@, detail=%@", response.getErrorReason, response.getErrorDetail);
        NSString *msg = [NSString stringWithFormat:@"Failed to cancel transaction: %@. Check EFTPOS.", response.getErrorDetail];
        [self.state.txFlowState cancelFailed:msg];
        [self transactionFlowStateChanged];
        [self sendTransactionReport];
        
        NSLog(@"handleCancelTxResp txLock exiting");
    }
}

/**
 * When the result response for the POS info is returned.
 *
 * @param m Message
 */
- (void)handleSetPosInfoResponse:(SPIMessage *)m {
    SPISetPosInfoResponse *response = [[SPISetPosInfoResponse alloc] initWithMessage:m];
    if (response.isSuccess) {
        self.hasSetPosInfo = YES;
        SPILog(@"Setting POS info successful");
    } else {
        SPILog(@"ERROR: Setting POS info failed: reason=@%, detail=%@", response.getErrorReason, response.getErrorDetail);
    }
}

- (void)transactionMonitoring {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        BOOL needsPublishing = NO;
        
        @synchronized(weakSelf.txLock) {
            SPITransactionFlowState *txState = weakSelf.state.txFlowState;
            
            if (weakSelf.state.flow == SPIFlowTransaction && !txState.isFinished) {
                SPITransactionFlowState *state = txState.copy;
                
                NSDate *now = [NSDate date];
                NSDate *cancel = [state.cancelAttemptTime dateByAddingTimeInterval:maxWaitForCancelTx];
                
                if (state.isAttemptingToCancel && [now compare:cancel] == NSOrderedDescending) {
                    // TH-2T - too long since cancel attempt - Consider unknown
                    SPILog(@"Been too long waiting for transaction to cancel.");
                    [txState unknownCompleted:@"Waited long enough for cancel transaction result. Check EFTPOS."];
                    needsPublishing = YES;
                } else if (state.isRequestSent && [now compare:[state.lastStateRequestTime dateByAddingTimeInterval: checkOnTxFrequency]] ==  NSOrderedDescending) {
                    //It's been a while since we received an update
                    if (weakSelf.state.txFlowState.type == SPITransactionTypeGetLastTransaction) {
                        // It is not possible to recover a GLT with a GT, so we send another GLT
                        weakSelf.state.txFlowState.lastStateRequestTime = [NSDate date];
                        [weakSelf send:[[SPIGetLastTransactionRequest new] toMessage]];
                        SPILog(@"Been to long waiting for GLT response. Sending another GLT. Last checked at $@...", [state.lastStateRequestTime toString]);
                    } else {
                        // let's call a GT to see what is happening
                        SPILog(@"Checking on our transaction. Last we asked was at %@...", [state.lastStateRequestTime toString]);
                        [weakSelf callGetTransaction:weakSelf.state.txFlowState.posRefId];
                    }
                    
                }
            }
        }
        
        if (needsPublishing) {
            [weakSelf transactionFlowStateChanged];
        }
    });
}

- (void)handlePrintingResponse:(SPIMessage *)m {
    if([_delegate respondsToSelector:@selector(printingResponse:)]) {
        [_delegate printingResponse:m];
    }
}

- (void)handleTerminalStatusResponse:(SPIMessage *)m {
    if([_delegate respondsToSelector:@selector(terminalStatusResponse:)]) {
        [_delegate terminalStatusResponse:m];
    }
}

- (void)handleTerminalConfigurationResponse:(SPIMessage *)m {
    self.terminalModel = [[[SPITerminalConfigurationResponse alloc] initWithMessage:m] getTerminalModel];
    if([_delegate respondsToSelector:@selector(terminalConfigurationResponse:)]) {
        [_delegate terminalConfigurationResponse:m];
    }
}

- (void)handleBatteryLevelChanged:(SPIMessage *)m {
    if([_delegate respondsToSelector:@selector(batteryLevelChanged:)]) {
        [_delegate batteryLevelChanged:m];
    }
}

- (void)handleUpdateMessage:(SPIMessage *)m {
    if([_delegate respondsToSelector:@selector(updateMessageReceived:)]) {
        [_delegate updateMessageReceived:m];
    }
}

#pragma mark - Internals for connection management

- (void)resetConnection {
    // Setup the connection
    self.connection.delegate = nil;
    self.connection = [[SPIWebSocketConnection alloc] initWithDelegate:self];
}

#pragma mark - SPIConnectionDelegate

/**
 * This method will be called when the connection status changes.
 * You are encouraged to display a PIN pad connection indicator on the POS screen.
 *
 * @param newConnectionState Connection state
 */
- (void)onSpiConnectionStatusChanged:(SPIConnectionState)newConnectionState {
    SPILog(@"Connection status changed: %ld", (long)newConnectionState);
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        switch (newConnectionState) {
            case SPIConnectionStateConnecting:
                SPILog(@"I'm connecting to the EFTPOS at %@...", weakSelf.eftposAddress);
                break;
                
            case SPIConnectionStateConnected:
                self.retriesSinceLastDeviceAddressResolution = 0;
                
                [self.spiMessageStamp resetConnection];
                
                if (weakSelf.state.flow == SPIFlowPairing && weakSelf.state.status == SPIStatusUnpaired) {
                    weakSelf.state.pairingFlowState.message = @"Requesting to pair...";
                    [weakSelf pairingFlowStateChanged];
                    
                    SPIPairingRequest *pr = [SPIPairingHelper newPairRequest];
                    [weakSelf send:[pr toMessage]];
                } else {
                    SPILog(@"I'm connected to %@", weakSelf.eftposAddress);
                    weakSelf.spiMessageStamp.secrets = weakSelf.secrets;
                    [weakSelf startPeriodicPing];
                }
                break;
                
            case SPIConnectionStateDisconnected:
                SPILog(@"I'm disconnected from %@", weakSelf.eftposAddress);
                // Let's reset some lifecycle related state, ready for next connection
                weakSelf.mostRecentPingSent = nil;
                weakSelf.mostRecentPongReceived = nil;
                weakSelf.missedPongsCount = 0;
                [weakSelf stopPeriodPing];
                [weakSelf.spiMessageStamp resetConnection];
                if (weakSelf.state.status != SPIStatusUnpaired) {
                    weakSelf.state.status = SPIStatusPairedConnecting;
                    [weakSelf statusChanged];
                    
                    if (weakSelf.state.flow == SPIFlowTransaction && !weakSelf.state.txFlowState.isFinished) {
                        // we're in the middle of a transaction, just so you know!
                        // TH-1D
                        SPILog(@"Lost connection in the middle of a transaction...");
                    }
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        if (weakSelf.connection == nil) return;
                        
                        if (self.autoAddressResolutionEnable) {
                            if (self.retriesSinceLastDeviceAddressResolution >= retriesBeforeResolvingDeviceAddress) {
                                [self autoResolveEftposAddress];
                                self.retriesSinceLastDeviceAddressResolution = 0;
                            } else {
                                self.retriesSinceLastDeviceAddressResolution += 1;
                            }
                        }
                        
                        SPILog(@"Will try to reconnect in 3s...");
                        sleep(3);
                        
                        if (weakSelf.state.status != SPIStatusUnpaired) {
                            [weakSelf.connection connect];
                        }
                    });
                } else if (weakSelf.state.flow == SPIFlowPairing) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        if (weakSelf.state.pairingFlowState.isFinished) return;
                        
                        if (self.retriesSinceLastPairing >= retriesBeforePairing) {
                            self.retriesSinceLastPairing = 0;
                            SPILog(@"Lost connection during pairing.");
                            [weakSelf onPairingFailed];
                            [weakSelf pairingFlowStateChanged];
                            return;
                        } else {
                            SPILog(@"Will try to re-pair in 3s...");
                            sleep(3);
                            
                            if (weakSelf.state.status != SPIStatusPairedConnected) {
                                [weakSelf.connection connect];
                            }
                            self.retriesSinceLastPairing += 1;
                        }
                    });
                }
                break;
        }
    });
}

#pragma mark - Ping

/**
 * This is an important piece of the puzzle. It's a background thread that
 * periodically sends pings to the server. If it doesn't receive pongs, it
 * considers the connection as broken so it disconnects.
 */
- (void)startPeriodicPing {
    __weak __typeof(&*self) weakSelf = self;
    
    _pingTimer = [[SPIRepeatingTimer alloc] initWithQueue:"com.mx51.ping"
                                                 interval:0
                                                    block:^{
        if (!weakSelf.connection.isConnected || weakSelf.secrets == nil) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [weakSelf stopPeriodPing];
            });
            return;
        }
        
        [weakSelf doPing];
        sleep(pongTimeout);
        
        if (weakSelf.mostRecentPingSent != nil && (weakSelf.mostRecentPongReceived == nil || weakSelf.mostRecentPongReceived.mid != weakSelf.mostRecentPingSent.mid)) {
            weakSelf.missedPongsCount += 1;
            SPILog(@"EFTPOS didn't reply to my ping. Missed count: %i", weakSelf.missedPongsCount / missedPongsToDisconnect);
            if (weakSelf.missedPongsCount < missedPongsToDisconnect) {
                SPILog(@"Trying another ping...");
                return;
            }
            
            // This means that we have reached missed pong limit.
            // We consider this connection as broken.
            // Let's disconnect.
            SPILog(@"Disconnecting...");
            [weakSelf.connection disconnect];
            
            return;
        }
        
        weakSelf.missedPongsCount = 0;
        sleep(pingFrequency - pongTimeout);
    }];
}

/**
 * We call this ourselves as soon as we're ready to transact with the PIN pad
 * after a connection is established. This function is effectively called after
 * we received the first Login Response from the PIN pad.
 */
- (void)onReadyToTransact {
    SPILog(@"Ready to transact: %lu, %d", (unsigned long)self.state.flow, (int)!self.state.txFlowState.isFinished);
    
    // So, we have just made a connection, pinged and logged in successfully.
    self.state.status = SPIStatusPairedConnected;
    [self statusChanged];
    
    __weak __typeof(& *self) weakSelf = self;
    
    NSLog(@"onReadyToTx txLock entering");
    @synchronized(self.txLock) {
        NSLog(@"onReadyToTx txLock entered");
        if (self.state.flow == SPIFlowTransaction && !self.state.txFlowState.isFinished) {
            if (self.state.txFlowState.isRequestSent) {
                // TH-3A - We've just reconnected and were in the middle of Tx.
                // Let's get the last transaction to check what we might have
                // missed out on.
                
                dispatch_async(self.queue, ^{
                    [weakSelf callGetTransaction:weakSelf.state.txFlowState.posRefId];
                });
            } else {
                // TH-3AR - We had not even sent the request yet. Let's do that now
                [self send:self.state.txFlowState.request];
                [self.state.txFlowState sent:@"Sending request now..."];
                [self transactionFlowStateChanged];
            }
        } else {
            dispatch_async(self.queue, ^{
                if (!self.hasSetPosInfo) {
                    [weakSelf callSetPosInfo];
                    weakSelf.transactionReport = [SPITransactionReportHelper createTransactionReportEnvelope:weakSelf.posVendorId posVersion:weakSelf.posVersion libraryLanguage:self.libraryLanguage libraryVersion:[SPIClient getVersion] serialNumber:weakSelf.serialNumber];
                }
                
                [weakSelf.spiPat pushPayAtTableConfig];
            });
            SPILog(@"Ready to transact and NOT in the middle of a transaction. Nothing to do.");
        }
        NSLog(@"onreadyToTx txLock exited");
    }
}

/**
 * When we disconnect, we should also stop the periodic ping.
 */
- (void)stopPeriodPing {
    SPILog(@"stopPeriodPing");
    
    // If we were already set up, clean up before restarting.
    _pingTimer = nil;
    SPILog(@"stoppedPeriodPing");
}

/**
 * Send a Ping to the Server
 */
- (void)doPing {
    NSLog(@"doPing");
    
    SPIMessage *ping = [SPIPingHelper generatePingRequest];
    self.mostRecentPingSent = ping;
    [self send:ping];
    self.mostRecentPingSentTime = [NSDate date].timeIntervalSince1970;
}

/**
 * Received a pong from the server.
 *
 * @param m Message
 */
- (void)handleIncomingPong:(SPIMessage *)m {
    NSLog(@"handleIncomingPong");
    
    
    
    if (self.mostRecentPongReceived == nil) {
        // First pong received after a connection, and after the pairing process is fully finalised.
        // Receive connection id from PinPad after first pong, store this as this needs to be passed for every request.
        [self.spiMessageStamp setConnectionId: m.connID];
        if (_state.status != SPIStatusUnpaired) {
            SPILog(@"First pong of connection and in paired state.");
            [self onReadyToTransact];
        } else {
            SPILog(@"First pong of connection but pairing process not finalised yet.");
        }
    }
    
    self.mostRecentPongReceived = m;
    SPILog(@"Pong latency: %f", [NSDate date].timeIntervalSince1970 - _mostRecentPingSentTime);
}

/**
 *
 * The server will also send us pings. We need to reply with a pong so it
 * doesn't disconnect us.
 *
 * @param m Message
 */
- (void)handleIncomingPing:(SPIMessage *)m {
    NSLog(@"handleIncomingPing");
    SPIMessage *pong = [SPIPongHelper generatePongRequest:m];
    [self send:pong];
}

#pragma mark - Internal calls

- (void)callSetPosInfo {
    [self send:[[[SPISetPosInfoRequest alloc] initWithVersion:self.posVersion
                                                     vendorId:self.posVendorId
                                              libraryLanguage:self.libraryLanguage
                                               libraryVersion:[SPIClient getVersion]
                                                    otherInfo:[SPIDeviceInfo getAppDeviceInfo]] toMessage]];
}

/**
 * Ask the PIN pad to tell about the transaction with the posRefId
 */

- (void)callGetTransaction:(NSString *)posRefId {
    SPIMessage *gtMessage = [[[SPIGetTransactionRequest alloc] initWithPosRefId:posRefId] toMessage];
    [self.state.txFlowState callingGt:gtMessage.mid];
    [self send:gtMessage];
}

/**
 * This method will be called whenever we receive a message from the connection.
 *
 * @param message Message
 */
- (void)onSpiMessageReceived:(NSString *)message {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        // First we parse the incoming message
        SPIMessage *m = [SPIMessage fromJson:message secrets:weakSelf.secrets];
        
        NSString *eventName = m.eventName;
        
        SPILog(@"Message received: %@", m.decryptedJson);
        
        if ([self.spiPreauth isPreauthEvent:eventName]) {
            [self.spiPreauth _handlePreauthMessage:m];
            return;
        }
        
        // And then we switch on the event type.
        if ([eventName isEqualToString:SPIKeyRequestKey]) {
            [weakSelf handleKeyRequest:m];
            
        } else if ([eventName isEqualToString:SPIKeyCheckKey]) {
            [weakSelf handleKeyCheck:m];
            
        } else if ([eventName isEqualToString:SPIPairResponseKey]) {
            [weakSelf handlePairResponse:m];
            
        } else if ([eventName isEqualToString:SPIDropKeysAdviceKey]) {
            [weakSelf handleDropKeysAdvice:m];
            
        } else if ([eventName isEqualToString:SPIPurchaseResponseKey]) {
            [weakSelf handlePurchaseResponse:m];
            
        } else if ([eventName isEqualToString:SPIRefundResponseKey]) {
            [weakSelf handleRefundResponse:m];
            
        } else if ([eventName isEqualToString:SPIReversalResponseKey]) {
            [weakSelf handleReversalResponse:m];
            
        }
        else if ([eventName isEqualToString:SPICashoutOnlyResponseKey]) {
            [weakSelf handleCashoutOnlyResponse:m];
            
        } else if ([eventName isEqualToString:SPIMotoPurchaseResponseKey]) {
            [weakSelf handleMotoPurchaseResponse:m];
            
        } else if ([eventName isEqualToString:SPISignatureRequiredKey]) {
            [weakSelf handleSignatureRequired:m];
            
        } else if ([eventName isEqualToString:SPIAuthCodeRequiredKey]) {
            [weakSelf handleAuthCodeRequired:m];
            
        } else if ([eventName isEqualToString:SPIGetLastTransactionResponseKey]) {
            [weakSelf handleGetLastTransactionResponse:m];
            
        } else if ([eventName isEqualToString:SPIGetTransactionResponseKey]) {
            [weakSelf handleGetTransactionResponse:m];
            
        } else if ([eventName isEqualToString:SPISettleResponseKey]) {
            [weakSelf handleSettleResponse:m];
            
        } else if ([eventName isEqualToString:SPISettlementEnquiryResponseKey]) {
            [weakSelf handleSettlementEnquiryResponse:m];
            
        } else if ([eventName isEqualToString:SPICancelTransactionResponseKey]) {
            [weakSelf handleCancelTransactionResponse:m];
            
        } else if ([eventName isEqualToString:SPISetPosInfoResponseKey]) {
            [weakSelf handleSetPosInfoResponse:m];
            
        } else if ([eventName isEqualToString:SPIPingKey]) {
            [weakSelf handleIncomingPing:m];
            
        } else if ([eventName isEqualToString:SPIPongKey]) {
            [weakSelf handleIncomingPong:m];
            
        } else if ([eventName isEqualToString:SPIKeyRollRequestKey]) {
            [weakSelf handleKeyRollingRequest:m];
            
        } else if ([eventName isEqualToString:SPIPayAtTableGetTableConfigKey]) {
            if (weakSelf.spiPat == nil) {
                [weakSelf send:[SPIPayAtTableConfig featureDisableMessage:[SPIRequestIdHelper idForString:@"patconf"]]];
                return;
            }
            [weakSelf.spiPat handleGetTableConfig:m];
            
        } else if ([eventName isEqualToString:SPIPayAtTableGetBillDetailsKey]) {
            [weakSelf.spiPat handleGetBillDetailsRequest:m];
            
        } else if ([eventName isEqualToString:SPIPayAtTableBillPaymentKey]) {
            [weakSelf.spiPat handleBillPaymentAdvice:m];
            
        } else if ([eventName isEqualToString:SPIPayAtTableGetOpenTablesKey]) {
            [weakSelf.spiPat handleGetOpenTablesRequest:m];
            
        } else if ([eventName isEqualToString:SPIPayAtTableBillPaymentFlowEndedKey]) {
            [weakSelf.spiPat handleBillPaymentFlowEnded:m];
            
        } else if ([eventName isEqualToString:SPIPrintingResponseKey]) {
            [weakSelf handlePrintingResponse:m];
            
        } else if ([eventName isEqualToString:SPITerminalStatusResponseKey]) {
            [weakSelf handleTerminalStatusResponse:m];
            
        } else if ([eventName isEqualToString:SPITerminalConfigurationResponseKey]) {
            [weakSelf handleTerminalConfigurationResponse:m];
            
        } else if ([eventName isEqualToString:SPIBatteryLevelChangedKey]) {
            [weakSelf handleBatteryLevelChanged:m];
            
        } else if ([eventName isEqualToString:SPITransactionUpdateKey]) {
            [weakSelf handleUpdateMessage:m];
        }
        else if ([eventName isEqualToString:SPIInvalidHmacSignature]) {
            SPILog(@"I could not verify message from EFTPOS. You might have to un-pair EFTPOS and then reconnect.");
            
        } else if ([eventName isEqualToString:SPIEventError]) {
            SPILog(@"ERROR: '%@', %@", eventName, m.data);
            [weakSelf handleErrorEvent:m];
            
        } else {
            SPILog(@"ERROR: I don't understand event: '%@', %@. Perhaps I have not implemented it yet.", eventName, m.data);
        }
    });
}

- (void)sendTransactionReport {
    
    NSTimeInterval duration = [self.state.txFlowState.completedDate timeIntervalSinceDate:self.state.txFlowState.requestDate];
    
    self.transactionReport.txType = [self.state.txFlowState txTypeString];
    self.transactionReport.txResult = [self successStateString:self.state.txFlowState.successState];
    self.transactionReport.txStartTime = [NSNumber numberWithLong:(self.state.txFlowState.requestDate.timeIntervalSince1970 * 1000.0)];
    self.transactionReport.txEndTime = [NSNumber numberWithLong:(self.state.txFlowState.completedDate.timeIntervalSince1970 * 1000.0)];
    self.transactionReport.durationMs = [NSNumber numberWithLong:(duration * 1000.0)];
    self.transactionReport.currentFlow = [SPIState flowString:self.state.flow];
    self.transactionReport.currentStatus = [self statusString:self.state.status];
    self.transactionReport.posRefId = self.state.txFlowState.posRefId;
    self.transactionReport.event = [NSString stringWithFormat:@"Waiting for Signature: %@, Attemtping to Cancel: %@, Finished: %@", self.state.txFlowState.isAwaitingSignatureCheck ? @"true" : @"false", self.state.txFlowState.isAttemptingToCancel ? @"true" : @"false", self.state.txFlowState.isFinished ? @"true" : @"false"];
    self.transactionReport.serialNumber = self.serialNumber;
    self.transactionReport.currentTxFlowState = [self.state.txFlowState txTypeString];
    
    
    [SPIAnalyticsService reportTransaction:self.transactionReport apiKey:self.deviceApiKey acquirerCode:self.acquirerCode isTestMode:self.testMode];
    
}

- (void)didReceiveError:(NSError *)error {
    dispatch_async(self.queue, ^{
        SPILog(@"ERROR: Received WS error: %@", error);
    });
}

- (BOOL)isPrintingConfigEnabled {
    if (self.config.promptForCustomerCopyOnEftpos || self.config.printMerchantCopy || self.config.signatureFlowOnEftpos) {
        return true;
    } else {
        return false;
    }
}

#pragma mark - Helpers

- (NSString *)successStateString:(SPIMessageSuccessState)state {
    switch (state) {
        case SPIMessageSuccessStateFailed:
            return @"Failed";
            break;
        case SPIMessageSuccessStateSuccess:
            return @"Success";
            break;
        case SPIMessageSuccessStateUnknown:
            return @"Unknown";
            break;
    }
}

- (NSString *)statusString:(SPIStatus)status {
    switch (status) {
        case SPIStatusPairedConnected:
            return @"PairedConnected";
            break;
        case SPIStatusUnpaired:
            return @"Unpaired";
            break;
        case SPIStatusPairedConnecting:
            return @"PairedConnecting";
            break;
    }
}

#pragma mark - Internals for Validations

- (BOOL)isPosIdValid:(NSString *)posId {
    if (posId.length == 0) {
        NSLog(@"Pos Id cannot be null or empty");
        return false;
    }
    
    if (posId.length > 16) {
        NSLog(@"Pos Id is greater than 16 characters");
        return false;
    }
    
    NSUInteger match = [_posIdRegex numberOfMatchesInString:posId options:0 range:NSMakeRange(0, [posId length])];
    
    if (posId.length != 0 && match == 0) {
        NSLog(@"The Pos Id can not include special characters");
        return false;
    }
    
    return true;
}

- (BOOL)isEftposAddressValid:(NSString *)eftposAddress {
    if (eftposAddress.length == 0) {
        NSLog(@"The Eftpos Address cannot be null or empty");
        return false;
    }
    
    eftposAddress = [eftposAddress stringByReplacingOccurrencesOfString:@"ws://" withString:@""];
    NSUInteger match = [_eftposAddressRegex numberOfMatchesInString:eftposAddress options:0 range:NSMakeRange(0, [eftposAddress length])];
    
    if (eftposAddress.length != 0 && match == 0) {
        NSLog(@"The Eftpos Address is not in right format");
        return false;
    }
    
    return true;
}

@end
