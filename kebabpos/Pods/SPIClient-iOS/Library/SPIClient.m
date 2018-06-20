//
//  SPIClient.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-28.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "NSObject+Util.h"
#import "NSString+Util.h"
#import "SPICashout.h"
#import "SPIClient.h"
#import "SPIConnection.h"
#import "SPIGCDTimer.h"
#import "SPIKeyRollingHelper.h"
#import "SPILogger.h"
#import "SPIMessage.h"
#import "SPIModels.h"
#import "SPIPairing.h"
#import "SPIPairingHelper.h"
#import "SPIPayAtTable.h"
#import "SPIPingHelper.h"
#import "SPIPreAuth.h"
#import "SPIPurchase.h"
#import "SPIPurchaseHelper.h"
#import "SPIRequestIdHelper.h"
#import "SPISettlement.h"
#import "SPIWebSocketConnection.h"
@interface SPIClient () <SPIConnectionDelegate>

// The current status of this SPI instance. Unpaired, PairedConnecting or
// PairedConnected.
@property (nonatomic, strong) SPIState *state;

@property (nonatomic, strong) id<SPIConnection> connection;

@property (nonatomic, strong) SPIMessageStamp *spiMessageStamp;
@property (nonatomic, strong) SPISecrets *secrets;
@property (nonatomic, strong) SPIPayAtTable *spiPat;
@property (nonatomic, strong) SPIPreAuth *spiPreauth;

@property (nonatomic, strong) SPIGCDTimer *pingTimer;
@property (nonatomic, strong) SPIGCDTimer *disconnectIfNeededSourceTimer;
@property (nonatomic, strong) SPIGCDTimer *transactionMonitoringTimer;

@property (nonatomic, strong) SPIMessage *mostRecentPingSent;
@property (nonatomic) NSTimeInterval mostRecentPingSentTime;
@property (nonatomic, strong) SPIMessage *mostRecentPongReceived;
@property (nonatomic, assign) NSInteger missedPongsCount;

//@property (nonatomic, strong) SPILoginResponse     *mostRecentLoginResponse;
@property (nonatomic, strong)
SPISignatureRequired *mostRecentSignatureRequiredReceived;

@property (nonatomic, assign) BOOL started;

@property (nonatomic, strong) dispatch_queue_t queue;

@end

static NSTimeInterval txMonitorCheckFrequency = 1; // How often do we check on the tx state from our tx monitoring thread

static NSTimeInterval checkOnTxFrequency = 20;  // How often do we proactively check on the tx status by calling get_last_transaction
static NSTimeInterval maxWaitForCancelTx = 10;  // How long do we wait for cancel to return before giving up completely.

static NSTimeInterval pongTimeout = 5; // How long do we wait for a pong to come back
static NSTimeInterval pingFrequency = 18; // How often we send pings
static NSInteger missedPongsToDisconnect = 2; // How many missed pongs before disconnecting

@implementation SPIClient

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _queue = dispatch_queue_create(
                                       "com.assemblypayments",
                                       dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,
                                                                               QOS_CLASS_DEFAULT, 0));
        
        _disconnectIfNeededSourceTimer = [[SPIGCDTimer alloc]
                                          initWithObject:self
                                          queue:"com.assemblypayments.disconnect"];
        _transactionMonitoringTimer = [[SPIGCDTimer alloc]
                                       initWithObject:self
                                       queue:"com.assemblypayments.txMonitor"];
        _config = [[SPIConfig alloc] init];
        _state = [SPIState new];
    }
    
    return self;
}

- (void)dealloc {
    _delegate = nil;
    [_connection disconnect];
    _connection.delegate = nil;
    _connection = nil;
    [_pingTimer cancel];
    [_disconnectIfNeededSourceTimer cancel];
    [_transactionMonitoringTimer cancel];
}

- (SPIPreAuth *)enablePreauth {
    _spiPreauth = [[SPIPreAuth alloc] init:self queue:_queue];
    return _spiPreauth;
}

- (SPIPayAtTable *)enablePayAtTable {
    _spiPat = [[SPIPayAtTable alloc] initWithClient:self];
    return _spiPat;
}

- (BOOL)start {
    if (self.started) {
        return false;
    }
    
    NSLog(@"start");
    
    if (self.posId) {
        // Our stamp for signing outgoing messages
        self.spiMessageStamp =  [[SPIMessageStamp alloc] initWithPosId:self.posId
                                       secrets:self.secrets
                               serverTimeDelta:0];
    }
    
    // Setup the Connection
    self.connection = [[SPIWebSocketConnection alloc] initWithDelegate:self];
    [self.connection setUrl:self.eftposAddress];
    
    [self.transactionMonitoringTimer afterDelay:txMonitorCheckFrequency
                                         repeat:YES
                                          block:^(id self) {
                                              [self transactionMonitoring];
                                          }];
    
    self.state.flow = SPIFlowIdle;
    self.started = true;
    
    if (self.secrets && self.eftposAddress) {
        NSLog(@"setup with secrets");
        
        self.state.status = SPIStatusPairedConnecting;
        [self.delegate spi:self statusChanged:self.state];
        [self connect];
        return NO;
    } else {
        NSLog(@"setup with NO secrets");
        
        self.state.status = SPIStatusUnpaired;
        [self.delegate spi:self statusChanged:self.state];
        return YES;
    }
}

- (NSString *)getVersion {
    return
    [[NSBundle bundleWithIdentifier:@"com.assemblypayments.SPIClient-iOS"]
     objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (void)setSecretEncKey:(NSString *)encKey hmacKey:(NSString *)hmacKey {
    self.secrets = [[SPISecrets alloc] initWithEncKey:encKey hmacKey:hmacKey];
}

- (BOOL)updatePosId:(NSString *)posId {
    if (self.state.status != SPIStatusUnpaired)
        return NO;
    
    _posId = posId.copy;
    self.spiMessageStamp.posId = posId;
    return YES;
}

- (BOOL)updateEftposAddress:(NSString *)eftposAddress {
    if (self.state.status != SPIStatusUnpaired)
        return NO;
    
    self.eftposAddress = eftposAddress;
    return YES;
}

- (void)ackFlowEndedAndBackToIdle:(SPICompletionState)completion {
    NSLog(@"ackFlowEndedAndBackToIdle");
    
    dispatch_async(self.queue, ^{
        if (self.state.flow == SPIFlowIdle) {
            return completion(YES, self.state); // already idle
        }
        
        if (self.state.flow == SPIFlowPairing &&
            self.state.pairingFlowState.isFinished) {
            self.state.flow = SPIFlowIdle;
            return completion(YES, self.state);
        }
        if (self.state.flow == SPIFlowTransaction &&
            self.state.txFlowState.isFinished) {
            self.state.flow = SPIFlowIdle;
            return completion(YES, self.state);
        }
        
        completion(NO, self.state.copy);
    });
}

#pragma mark -  Pairing Flow Methods

- (void)pair {
    NSLog(@"pair");
    
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        if (weakSelf.state.status != SPIStatusUnpaired)
            return;
        
        SPIPairingFlowState *currentPairingFlowState = [SPIPairingFlowState new];
        currentPairingFlowState.message = @"Connecting...";
        currentPairingFlowState.confirmationCode = @"";
        currentPairingFlowState.isAwaitingCheckFromEftpos = NO;
        currentPairingFlowState.isAwaitingCheckFromPos = NO;
        
        weakSelf.state.flow = SPIFlowPairing;
        weakSelf.state.pairingFlowState = currentPairingFlowState;
        
        [weakSelf.delegate spi:weakSelf pairingFlowStateChanged:weakSelf.state];
        [weakSelf.connection connect];
    });
}

- (void)pairingConfirmCode {
    __weak __typeof(&*self) weakSelf = self;
    
    NSLog(@"pairingConfirmCode isAwaitingCheckFromEftpos=%@",
          @(weakSelf.state.pairingFlowState.isAwaitingCheckFromEftpos));
    
    if (!weakSelf.state.pairingFlowState.isAwaitingCheckFromPos) {
        // We weren't expecting this
        return;
    }
    
    weakSelf.state.pairingFlowState.isAwaitingCheckFromPos = NO;
    
    if (weakSelf.state.pairingFlowState.isAwaitingCheckFromEftpos) {
        // But we are still waiting for confirmation from EFTPOS side.
        weakSelf.state.pairingFlowState.message = [NSString
                                                   stringWithFormat:@"Click YES on EFTPOS if code is: %@",
                                                   weakSelf.state.pairingFlowState.confirmationCode];
        [weakSelf.delegate spi:weakSelf pairingFlowStateChanged:weakSelf.state];
    } else {
        NSLog(@"pairedReady");
        // Already confirmed from EFTPOS - So all good now. We're Paired also
        // from the POS perspective.
        weakSelf.state.pairingFlowState.message = @"Pairing successful";
        [weakSelf onPairingSuccess];
        [weakSelf onReadyToTransact];
    }
}

- (void)pairingCancel {
    if (_state.flow != SPIFlowPairing || _state.pairingFlowState.isFinished) {
        return;
    }
    if (_state.pairingFlowState.isAwaitingCheckFromPos &&
        !_state.pairingFlowState.isAwaitingCheckFromEftpos) {
        SPIMessage *message = [[[SPIDropKeysRequest alloc] init] toMessage];
        [self send:message];
    }
    [self onPairingFailed];
}

- (void)unpair {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"unpair");
        
        if (weakSelf.state.status == SPIStatusUnpaired)
            return;
        
        if (weakSelf.state.flow != SPIFlowIdle)
            return;
        
        weakSelf.state.status = SPIStatusUnpaired;
        weakSelf.state.pairingFlowState = nil;
        weakSelf.state.txFlowState = nil;
        [weakSelf.delegate spi:self statusChanged:weakSelf.state];
        
        [weakSelf.connection disconnect];
        weakSelf.secrets = nil;
        weakSelf.spiMessageStamp.secrets = nil;
        [weakSelf.delegate spi:weakSelf secretsChanged:nil state:weakSelf.state];
    });
}

#pragma mark - Transactions

- (void)initiatePurchaseTx:(NSString *)pid
               amountCents:(NSInteger)amountCents
                completion:(SPICompletionTxResult)completion {
    SPILog(@"initiatePurchaseTx");
    
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:NO
                    message:@"Not paired"]);
        return;
    }
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        if (self.state.flow != SPIFlowIdle) {
            completion([[SPIInitiateTxResult alloc]
                        initWithTxResult:NO
                        message:@"Not idle"]);
            return;
        }
        SPIPurchaseRequest *purchase =
        [[SPIPurchaseRequest alloc] initWithAmountCents:amountCents
                                               posRefId:pid];
        purchase.config = weakSelf.config;
        SPIMessage *purchaseMessage = [purchase toMessage];
        weakSelf.state.flow = SPIFlowTransaction;
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc]
                                      initWithTid:pid
                                      type:SPITransactionTypePurchase
                                      amountCents:amountCents
                                      message:purchaseMessage
                                      msg:[NSString
                                           stringWithFormat:@"Waiting for EFTPOS connection to "
                                           @"make payment request for $%.2f",
                                           amountCents / 100.0]];
        if ([weakSelf send:purchaseMessage]) {
            [weakSelf.state.txFlowState
             sent:[NSString stringWithFormat:
                   @"Asked EFTPOS to accept payment for $%.2f",
                   amountCents / 100.0]];
        }
        
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:YES
                    message:@"Purchase initiated"]);
        
        [weakSelf.delegate spi:self transactionFlowStateChanged:weakSelf.state];
    });
}

- (void)initiatePurchaseTx:(NSString *)posRefId
            purchaseAmount:(int)purchaseAmount
                 tipAmount:(int)tipAmount
             cashoutAmount:(int)cashoutAmount
          promptForCashout:(bool)promptForCashout
                completion:(SPICompletionTxResult)completion {
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:NO
                    message:@"Not paired"]);
        return;
    }
    if (tipAmount > 0 && (cashoutAmount > 0 || promptForCashout)) {
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:NO
                    message:@"Cannot Accept Tips and Cashout at the same time."]);
    }
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        if (weakSelf.state.flow != SPIFlowIdle) {
            completion([[SPIInitiateTxResult alloc]
                        initWithTxResult:NO
                        message:@"Not idle"]);
        }
        weakSelf.state.flow = SPIFlowTransaction;
        SPIPurchaseRequest *purchase =
        [SPIPurchaseHelper createPurchaseRequestV2:posRefId
                                    purchaseAmount:purchaseAmount
                                         tipAmount:tipAmount
                                        cashAmount:cashoutAmount
                                  promptForCashout:promptForCashout];
        purchase.config = weakSelf.config;
        SPIMessage *purchaseMessage = [purchase toMessage];
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc]
                                      initWithTid:posRefId
                                      type:SPITransactionTypePurchase
                                      amountCents:purchaseAmount
                                      message:purchaseMessage
                                      msg:[NSString
                                           stringWithFormat:@"Waiting for EFTPOS connection to make payment request. %@",
                                           [purchase amountSummary]]];
        if ([weakSelf send:purchaseMessage]) {
            [weakSelf.state.txFlowState
             sent:[NSString stringWithFormat:
                   @"Asked EFTPOS to accept payment for %@}",
                   [purchase amountSummary]]];
        }
    });
    [weakSelf.delegate spi:self transactionFlowStateChanged:_state];
    completion([[SPIInitiateTxResult alloc]
                initWithTxResult:YES
                message:@"Purchase Initiated"]);
}

- (void)initiatePurchaseTxV2:(NSString *)posRefId
              purchaseAmount:(NSInteger)purchaseAmount
                   tipAmount:(NSInteger)tipAmount
               cashoutAmount:(NSInteger)cashoutAmount
            promptForCashout:(BOOL)promptForCashout
                  completion:(SPICompletionTxResult)completion {
    
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:NO
                    message:@"Not paired"]);
        return;
    }
    
    if (tipAmount > 0 && (cashoutAmount > 0 || promptForCashout)) {
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:NO
                    message:@"Cannot Accept Tips and Cashout at the same time."]);
    }
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        if (weakSelf.state.flow != SPIFlowIdle) {
            completion([[SPIInitiateTxResult alloc]
                        initWithTxResult:NO
                        message:@"Not idle"]);
        }
        weakSelf.state.flow = SPIFlowTransaction;
        
        SPIPurchaseRequest *purchase =
        [SPIPurchaseHelper createPurchaseRequestV2:posRefId
                                    purchaseAmount:purchaseAmount
                                         tipAmount:tipAmount
                                        cashAmount:cashoutAmount
                                  promptForCashout:promptForCashout];
        purchase.config = weakSelf.config;
        SPIMessage *purchaseMsg = [purchase toMessage];
        
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc]
                                      initWithTid:posRefId
                                      type:SPITransactionTypePurchase
                                      amountCents:purchaseAmount
                                      message:purchaseMsg
                                      msg:[NSString
                                           stringWithFormat:@"Waiting for EFTPOS connection to make payment request. %@",
                                           [purchase amountSummary]]];
        if ([weakSelf send:purchaseMsg]) {
            [weakSelf.state.txFlowState
             sent:[NSString stringWithFormat:
                   @"Asked EFTPOS to accept payment for %@}",
                   [purchase amountSummary]]];
        }
    });
    [weakSelf.delegate spi:self transactionFlowStateChanged:_state.copy];
    completion([[SPIInitiateTxResult alloc]
                initWithTxResult:YES
                message:@"Purchase Initiated"]);
}

- (void)initiateRefundTx:(NSString *)pid
             amountCents:(NSInteger)amountCents
              completion:(SPICompletionTxResult)completion {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        SPILog(@"initiateRefundTx");
        
        if (weakSelf.state.status == SPIStatusUnpaired)
            return completion([[SPIInitiateTxResult alloc]
                               initWithTxResult:NO
                               message:@"Not paired"]);
        
        if (weakSelf.state.flow != SPIFlowIdle)
            return completion([[SPIInitiateTxResult alloc]
                               initWithTxResult:NO
                               message:@"Not idle"]);
        
        SPIRefundRequest *refund =
        [[SPIRefundRequest alloc] initWithPosRefId:pid
                                       amountCents:amountCents];
        refund.config = weakSelf.config;
        weakSelf.state.flow = SPIFlowTransaction;
        SPIMessage *purchaseMessage = [refund toMessage];
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc]
                                      initWithTid:pid
                                      type:SPITransactionTypeRefund
                                      amountCents:amountCents
                                      message:purchaseMessage
                                      msg:[NSString
                                           stringWithFormat:@"Waiting for EFTPOS connection to make refund request for $%.2f",
                                           amountCents / 100.0]];
        
        if ([weakSelf send:purchaseMessage]) {
            [weakSelf.state.txFlowState
             sent:[NSString stringWithFormat:@"Asked EFTPOS to refund $%.2f", amountCents / 100.0]];
        }
        
        [weakSelf.delegate spi:weakSelf transactionFlowStateChanged:weakSelf.state];
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:YES
                    message:@"Refund initiated"]);
    });
}

- (void)acceptSignature:(BOOL)accepted {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        SPILog(@"acceptSignature");
        
        if (weakSelf.state.flow != SPIFlowTransaction ||
            weakSelf.state.txFlowState.isFinished ||
            !weakSelf.state.txFlowState.isAwaitingSignatureCheck) {
            SPILog(@"Asked to accept signature but I was not waiting for one.");
            return;
        }
        
        [weakSelf.state.txFlowState signatureResponded:accepted ? @"Accepting signature..." : @"Declining signature..."];
        
        NSString *sigReqMsgId = self.state.txFlowState.signatureRequiredMessage.requestId;
        SPIMessage *msg;
        if (accepted) {
            msg = [[[SPISignatureAccept alloc] initWithSignatureRequiredRequestId:sigReqMsgId] toMessage];
        } else {
            msg = [[[SPISignatureDecline alloc] initWithSignatureRequiredRequestId:sigReqMsgId] toMessage];
        }
        
        [weakSelf send:msg];
        
        [weakSelf.delegate spi:weakSelf transactionFlowStateChanged:weakSelf.state];
    });
}

- (void)initiateCashoutOnlyTx:(NSString *)posRefId
                  amountCents:(NSInteger)amountCents
                   completion:(SPICompletionTxResult)completion {
    __weak __typeof(&*self) weakSelf = self;
    
    if (weakSelf.state.status == SPIStatusUnpaired) {
        return completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
    }
    dispatch_async(self.queue, ^{
        if (weakSelf.state.flow != SPIFlowIdle) {
            return completion([[SPIInitiateTxResult alloc]
                               initWithTxResult:NO
                               message:@"Not Idle"]);
        }
        CashoutOnlyRequest *cashoutOnlyRequest =
        [[CashoutOnlyRequest alloc] initWithAmountCents:amountCents
                                               posRefId:posRefId];
        cashoutOnlyRequest.config = weakSelf.config;
        SPIMessage *cashoutMsg = [cashoutOnlyRequest toMessage];
        weakSelf.state.flow = SPIFlowTransaction;
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc]
                                      initWithTid:posRefId
                                      type:SPITransactionTypeCashoutOnly
                                      amountCents:amountCents
                                      message:cashoutMsg
                                      msg:[NSString
                                           stringWithFormat:@"Waiting for EFTPOS connection to send cashout request for $%.2f",
                                           ((float)amountCents / 100.0)]];
        if ([weakSelf send:cashoutMsg]) {
            [weakSelf.state.txFlowState sent:[NSString stringWithFormat:@"Asked EFTPOS to do cashout for $%.2f", ((float)amountCents / 100.0)]];
        }
        [weakSelf.delegate spi:weakSelf transactionFlowStateChanged:weakSelf.state];
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:YES
                    message:@"Cashout Initiated"]);
    });
}

- (void)initiateMotoPurchaseTx:(NSString *)posRefId
                   amountCents:(NSInteger)amountCents
                    completion:(SPICompletionTxResult)completion {
    __weak __typeof(&*self) weakSelf = self;
    
    if (weakSelf.state.status == SPIStatusUnpaired) {
        return completion([[SPIInitiateTxResult alloc]
                           initWithTxResult:NO
                           message:@"Not paired"]);
    }
    dispatch_async(self.queue, ^{
        if (weakSelf.state.flow != SPIFlowIdle) {
            return completion([[SPIInitiateTxResult alloc]
                               initWithTxResult:NO
                               message:@"Not Idle"]);
        }
        SPIMotoPurchaseRequest *motoPurchaseRequest =
        [[SPIMotoPurchaseRequest alloc] initWithAmountCents:amountCents
                                                   posRefId:posRefId];
        motoPurchaseRequest.config = weakSelf.config;
        SPIMessage *cashoutMsg = [motoPurchaseRequest toMessage];
        weakSelf.state.flow = SPIFlowTransaction;
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc]
                                      initWithTid:posRefId
                                      type:SPITransactionTypeMOTO
                                      amountCents:amountCents
                                      message:cashoutMsg
                                      msg:[NSString
                                           stringWithFormat:@"Waiting for EFTPOS connection to send MOTO request for %.2f",
                                           ((float)amountCents) / 100]];
        if ([weakSelf send:cashoutMsg]) {
            [weakSelf.state.txFlowState
             sent:[NSString stringWithFormat:@"Asked EFTPOS do MOTO for  %.2f",
                   ((float)amountCents) / 100]];
        }
    });
    [weakSelf.delegate spi:self transactionFlowStateChanged:weakSelf.state];
    completion([[SPIInitiateTxResult alloc]
                initWithTxResult:YES
                message:@"MOTO Initiated"]);
}

- (void)submitAuthCode:(NSString *)authCode
            completion:(SPIAuthCodeSubmitCompletionResult)completion {
    __weak __typeof(&*self) weakSelf = self;
    
    if (authCode.length != 6) {
        return completion([[SPISubmitAuthCodeResult alloc]
                           initWithValidFormat:false
                           msg:@"Not a 6-digit code."]);
    }
    
    dispatch_async(self.queue, ^{
        if (weakSelf.state.flow != SPIFlowTransaction ||
            weakSelf.state.txFlowState.isFinished ||
            !weakSelf.state.txFlowState.isAwaitingPhoneForAuth) {
            SPILog(@"Asked to send auth code but I was not waiting for one.");
            completion([[SPISubmitAuthCodeResult alloc]
                        initWithValidFormat:false
                        msg:@"Was not waiting for one."]);
        }
        [weakSelf.state.txFlowState
         authCodeSent:[NSString stringWithFormat:@"Submitting Auth Code %@", authCode]];
        
        SPIMessage *message = [[[SPIAuthCodeAdvice alloc]
                                initWithPosRefId:weakSelf.state.txFlowState.posRefId
                                authCode:authCode] toMessage];
        [self send:message];
    });
    
    [weakSelf.delegate spi:self transactionFlowStateChanged:_state];
    completion([[SPISubmitAuthCodeResult alloc]
                initWithValidFormat:true
                msg:@"Valid Code"]);
}

- (void)cancelTransaction {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        SPILog(@"cancelTransaction");
        
        if (weakSelf.state.flow != SPIFlowTransaction ||
            weakSelf.state.txFlowState.isFinished) {
            SPILog(@"Asked to cancel transaction but I was not in the middle of one.");
            return;
        }
        
        // TH-1C, TH-3C - Merchant pressed cancel
        if (weakSelf.state.txFlowState.isRequestSent) {
            SPICancelTransactionRequest *cancelReq =
            [SPICancelTransactionRequest new];
            [weakSelf.state.txFlowState
             cancelling:@"Attempting to cancel transaction..."];
            [weakSelf send:[cancelReq toMessage]];
        } else {
            // We Had Not Even Sent Request Yet. Consider as known failed.
            [weakSelf.state.txFlowState failed:nil
                                           msg:@"Transaction cancelled. Request had not even been sent yet."];
        }
        
        [weakSelf.delegate spi:weakSelf
   transactionFlowStateChanged:weakSelf.state];
    });
}

- (void)initiateSettleTx:(NSString *)pid
              completion:(SPICompletionTxResult)completion {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        if (weakSelf.state.status == SPIStatusUnpaired)
            return completion([[SPIInitiateTxResult alloc]
                               initWithTxResult:NO
                               message:@"Not paired"]);
        
        if (weakSelf.state.flow != SPIFlowIdle)
            return completion([[SPIInitiateTxResult alloc]
                               initWithTxResult:NO
                               message:@"Not idle"]);
        
        SPISettleRequest *settleRequest = [[SPISettleRequest alloc]
                                           initWithSettleId:[SPIRequestIdHelper idForString:@"settle"]];
        
        weakSelf.state.flow = SPIFlowTransaction;
        SPIMessage *settleMessage = [settleRequest toMessage];
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc]
                                      initWithTid:pid
                                      type:SPITransactionTypeSettle
                                      amountCents:0
                                      message:settleMessage
                                      msg:@"Waiting for EFTPOS connection to make a settle request"];
        
        if ([weakSelf send:settleMessage]) {
            [weakSelf.state.txFlowState sent:@"Asked EFTPOS to settle."];
        }
        
        [weakSelf.delegate spi:weakSelf
   transactionFlowStateChanged:weakSelf.state];
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:YES
                    message:@"Settle initiated"]);
    });
}

- (void)initiateSettlementEnquiry:(NSString *)posRefId
                       completion:(SPICompletionTxResult)completion {
    __weak __typeof(&*self) weakSelf = self;
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:NO
                    message:@"Not Paired"]);
    }
    
    dispatch_async(self.queue, ^{
        if (self.state.flow != SPIFlowIdle) {
            completion([[SPIInitiateTxResult alloc]
                        initWithTxResult:NO
                        message:@"Not Idle"]);
        }
        
        SPIMessage *stlEnqMsg = [[[SPISettlementEnquiryRequest alloc]
                                  initWithRequestId:[SPIRequestIdHelper idForString:@"stlenq"]]
                                 toMessage];
        self.state.flow = SPIFlowTransaction;
        self.state.txFlowState = [[SPITransactionFlowState alloc]
                                  initWithTid:posRefId
                                  type:SPITransactionTypeSettleEnquiry
                                  amountCents:0
                                  message:stlEnqMsg
                                  msg:@"Waiting for EFTPOS connection to make a settlement enquiry"];
        if ([self send:stlEnqMsg]) {
            [self.state.txFlowState
             sent:@"Asked EFTPOS to make a settlement enquiry."];
        }
    });
    [weakSelf.delegate spi:self transactionFlowStateChanged:weakSelf.state];
    
    completion([[SPIInitiateTxResult alloc]
                initWithTxResult:YES
                message:@"Settle Initiated"]);
}

- (void)initiateGetLastTxWithCompletion:(SPICompletionTxResult)completion {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        if (weakSelf.state.status == SPIStatusUnpaired)
            return completion([[SPIInitiateTxResult alloc]
                               initWithTxResult:NO
                               message:@"Not paired"]);
        
        if (weakSelf.state.flow != SPIFlowIdle)
            return completion([[SPIInitiateTxResult alloc]
                               initWithTxResult:NO
                               message:@"Not idle"]);
        
        SPIGetLastTransactionRequest *gltRequest =
        [SPIGetLastTransactionRequest new];
        
        weakSelf.state.flow = SPIFlowTransaction;
        SPIMessage *gltMessage = [gltRequest toMessage];
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc]
                                      initWithTid:gltMessage.mid
                                      type:SPITransactionTypeGetLastTransaction
                                      amountCents:0
                                      message:gltMessage
                                      msg:@"Waiting for EFTPOS connection to make a get last transaction request"];
        
        if ([weakSelf send:gltMessage]) {
            [weakSelf.state.txFlowState
             sent:@"Asked EFTPOS to get last transaction."];
        }
        
        [weakSelf.delegate spi:weakSelf
   transactionFlowStateChanged:weakSelf.state];
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:YES
                    message:@"Get last transaction initiated"]);
    });
}

- (void)initiateRecovery:(NSString *)posRefId
         transactionType:(SPITransactionType)txType
              completion:(SPICompletionTxResult)completion {
    
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc]
                    initWithTxResult:false
                    message:@"Not Paired"]);
    }
    
    dispatch_async(self.queue, ^{
        if (self.state.flow != SPIFlowIdle) {
            completion([[SPIInitiateTxResult alloc]
                        initWithTxResult:false
                        message:@"Not Idle"]);
        }
        self.state.flow = SPIFlowTransaction;
        
        SPIGetLastTransactionRequest *gtlRequest =
        [[SPIGetLastTransactionRequest alloc] init];
        SPIMessage *gltRequestMsg = [gtlRequest toMessage];
        self.state.txFlowState = [[SPITransactionFlowState alloc]
                                  initWithTid:posRefId
                                  type:txType
                                  amountCents:0
                                  message:gltRequestMsg
                                  msg:@"Waiting for EFTPOS connection to attempt recovery."];
        if ([self send:gltRequestMsg]) {
            [self.state.txFlowState sent:@"Asked EFTPOS to recover state."];
        }
    });
    [self.delegate spi:self transactionFlowStateChanged:self.state];
    completion([[SPIInitiateTxResult alloc]
                initWithTxResult:YES
                message:@"Recovery Initiated"]);
}

- (void)canceltransactionMonitoringTimer {
    [self.transactionMonitoringTimer cancel];
}

- (void)setEftposAddress:(NSString *)url {
    if (url.length == 0) {
        [self.connection setUrl:nil];
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
    _posId = posId.copy;
    NSLog(@"setPosId: %@ and set spiMessageStamp", _posId);
    
    if (_posId.length == 0) {
        return;
    }
    
    self.spiMessageStamp = [[SPIMessageStamp alloc] initWithPosId:posId
                                                          secrets:nil
                                                  serverTimeDelta:0];
}

/**
 * Events the are triggered:
 * SPIKeyRequestKey
 * SPIKeyCheckKey
 **/
- (void)connect {
    NSLog(@"connecting %@ %@", self.posId, self.eftposAddress);
    
    if (!self.secrets) {
        SPILog(@"Select the \"Pair with POS\" option on the EFTPOS terminal screen. Once selected, the EFTPOS terminal screen should read \"Start POS Pairing\"");
    }
    
    // Actually do connection.
    // This is non-blocking
    [self.connection connect];
}

- (void)disconnect {
    NSLog(@"disconnect");
    [self.connection disconnect];
}

- (BOOL)send:(SPIMessage *)message {
    NSString *json = [message toJson:self.spiMessageStamp];
    
    if (self.connection.isConnected) {
        SPILog(@"Sending: %@", message.decryptedJson);
        [self.connection send:json];
        return YES;
    } else {
        SPILog(@"Asked to send, but not connected: %@", message.decryptedJson);
        return NO;
    }
}

#pragma mark - EVENTS

/**
 * Handling the 2nd interaction of the pairing process, i.e. an incoming
 * KeyRequest.
 *
 * @param m Message
 */
- (void)handleKeyRequest:(SPIMessage *)m {
    SPILog(@"handleKeyRequest");
    
    self.state.pairingFlowState.message = @"Negotiating pairing...";
    [self.delegate spi:self pairingFlowStateChanged:self.state];
    
    // Use the helper. It takes the incoming request, and generates the secrets
    // and the response.
    SPISecretsAndKeyResponse *result = [SPIPairingHelper
                                        generateSecretsAndKeyResponseForKeyRequest:[[SPIKeyRequest alloc]
                                                                                    initWithMessage:m]];
    self.secrets = result.secrets; // we now have secrets, although pairing is not fully finished yet.
    self.spiMessageStamp.secrets = self.secrets; // updating our stamp with the secrets so can encrypt messages later.
    [self send:[result.keyResponse toMessage]]; // send the key_response, i.e. interaction 3 of pairing.
}

/**
 *
 * Handling the 4th interaction of the pairing process i.e. an incoming
 * KeyCheck.
 *
 * @param m Message
 */
- (void)handleKeyCheck:(SPIMessage *)m {
    SPILog(@"handleKeyCheck");
    
    SPIKeyCheck *keyCheck = [[SPIKeyCheck alloc] initWithMessage:m];
    self.state.pairingFlowState.confirmationCode = keyCheck.confirmationCode;
    self.state.pairingFlowState.isAwaitingCheckFromEftpos = YES;
    self.state.pairingFlowState.isAwaitingCheckFromPos = YES;
    self.state.pairingFlowState.message = [NSString stringWithFormat:@"Confirm that the following Code:\n\n%@\n\n is showing on the terminal",
                                           keyCheck.confirmationCode];
    [self.delegate spi:self pairingFlowStateChanged:self.state];
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
            SPILog(@"Got Pair Confirm from Eftpos, but still waiting for use to confirm from POS.");
            // Still Waiting for User to say yes on POS
            self.state.pairingFlowState.message = [NSString
                                                   stringWithFormat:
                                                   @"Confirm that the following Code:\n\n%@\n\n "
                                                   @"is what the EFTPOS showed",
                                                   self.state.pairingFlowState.confirmationCode];
            [self.delegate spi:self pairingFlowStateChanged:self.state];
        } else {
            SPILog(@"Got Pair Confirm from Eftpos, and already had confirm from POS. Now just waiting for first pong.");
            [self onPairingSuccess];
        }
        
        // I need to ping/login even if the pos user has not said yes yet,
        // because otherwise within 5 seconds connectiong will be dropped by
        // eftpos.
        [self startPeriodicPing];
    } else {
        [self onPairingFailed];
    }
}

- (void)handleDropKeysAdvice:(SPIMessage *)message {
    SPILog(@"Eftpos was Unpaired. I shall unpair from my end as well.");
    [self doUnpair];
}

- (void)doUnpair {
    _state.status = SPIStatusUnpaired;
    [_delegate spi:self statusChanged:_state];
    [_connection disconnect];
    _secrets = nil;
    _spiMessageStamp.secrets = nil;
    [_delegate spi:self secretsChanged:_secrets state:_state];
}

- (void)onPairingSuccess {
    NSLog(@"onPairingSuccess");
    
    self.state.pairingFlowState.isSuccessful = YES;
    self.state.pairingFlowState.isFinished = YES;
    self.state.pairingFlowState.message = @"Pairing successful!";
    self.state.status = SPIStatusPairedConnected;
    [self.delegate spi:self secretsChanged:self.secrets state:self.state];
    [self.delegate spi:self pairingFlowStateChanged:self.state.copy];
}

- (void)onPairingFailed {
    NSLog(@"onPairingFailed");
    
    self.secrets = nil;
    self.spiMessageStamp.secrets = nil;
    [self.connection disconnect];
    
    self.state.status = SPIStatusUnpaired;
    [_delegate spi:self statusChanged:_state];
    
    self.state.pairingFlowState.message = @"Pairing Failed";
    self.state.pairingFlowState.isFinished = YES;
    self.state.pairingFlowState.isSuccessful = NO;
    self.state.pairingFlowState.isAwaitingCheckFromPos = NO;
    [self.delegate spi:self pairingFlowStateChanged:self.state.copy];
}

/**
 * Sometimes the server asks us to roll our secrets.
 *
 * @param m Message
 */
- (void)handleKeyRollingRequest:(SPIMessage *)m {
    NSLog(@"handleKeyRollingRequest");
    // we calculate the new ones...
    SPIKeyRollingResult *krRes =
    [SPIKeyRollingHelper performKeyRollingWithMessage:m
                                       currentSecrets:self.secrets];
    self.secrets = krRes.secrets;                // and update our secrets with them
    self.spiMessageStamp.secrets = self.secrets; // and our stamp
    [self send:krRes.keyRollingConfirmation];
    [self.delegate spi:self secretsChanged:self.secrets state:self.state];
    
    // ylee
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
    __weak __typeof(&*self) weakSelf = self;
    dispatch_async(self.queue, ^{
        NSString *incomingPosRefId = [m getDataStringValue:@"pos_ref_id"];
        if (weakSelf.state.flow != SPIFlowTransaction ||
            weakSelf.state.txFlowState.isFinished ||
            ![weakSelf.state.txFlowState.posRefId isEqualToString:incomingPosRefId]) {
            SPILog(@"Received signature required but I was not waiting for one. %@", m.decryptedJson);
            return;
        }
        [self.state.txFlowState signatureRequired:[[SPISignatureRequired alloc] initWithMessage:m] msg:@"Ask customer to sign the receipt"];
    });
    
    [self.delegate spi:self transactionFlowStateChanged:self.state.copy];
}

- (void)handleAuthCodeRequired:(SPIMessage *)m {
    NSLog(@"handleAuthCodeRequired");
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSString *incomingPosRefId = [m getDataStringValue:@"pos_ref_id"];
        if (weakSelf.state.flow != SPIFlowTransaction ||
            weakSelf.state.txFlowState.isFinished ||
            ![weakSelf.state.txFlowState.posRefId isEqualToString:incomingPosRefId]) {
            SPILog(@"Received Auth Code Required but I was not waiting for one. Incoming Pos Ref ID: %@",
                   incomingPosRefId);
            return;
        }
        SPIPhoneForAuthRequired *phoneForAuthRequired =
        [[SPIPhoneForAuthRequired alloc] initWithMessage:m];
        NSString *msg =
        [NSString stringWithFormat:
         @"Auth Code Required. Call %@ and quote merchant id %@",
         phoneForAuthRequired.getPhoneNumber,
         phoneForAuthRequired.getMerchantId];
        [weakSelf.state.txFlowState phoneForAuthRequired:phoneForAuthRequired
                                                     msg:msg];
    });
    [weakSelf.delegate spi:self transactionFlowStateChanged:_state];
}

- (void)handleCashoutOnlyResponse:(SPIMessage *)m {
    NSLog(@"handleCashoutOnlyResponse");
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSString *incomingPosRefId = [m getDataStringValue:@"pos_ref_id"];
        if (weakSelf.state.flow != SPIFlowTransaction ||
            weakSelf.state.txFlowState.isFinished ||
            ![weakSelf.state.txFlowState.posRefId isEqualToString:incomingPosRefId]) {
            SPILog(@"Received Cashout Response but I was not waiting for one. Incoming Pos Ref ID:  %@", incomingPosRefId);
            return;
        }
        // TH-1A, TH-2A
        [weakSelf.state.txFlowState completed:[m successState]
                                     response:m
                                          msg:@"Cashout Transaction Ended."];
        // TH-6A, TH-6E
    });
    [weakSelf.delegate spi:self transactionFlowStateChanged:_state];
}

- (void)handleMotoPurchaseResponse:(SPIMessage *)m {
    NSLog(@"handleMotoPurchaseResponse");
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSString *incomingPosRefId = [m getDataStringValue:@"pos_ref_id"];
        if (weakSelf.state.flow != SPIFlowTransaction ||
            weakSelf.state.txFlowState.isFinished ||
            ![weakSelf.state.txFlowState.posRefId
              isEqualToString:incomingPosRefId]) {
                SPILog(@"Received Cashout Response but I was not waiting for one. Incoming Pos Ref ID: %@", incomingPosRefId);
                return;
            }
        // TH-1A, TH-2A
        [weakSelf.state.txFlowState completed:[m successState]
                                     response:m
                                          msg:@"Moto Transaction Ended."];
        // TH-6A, TH-6E
    });
    [weakSelf.delegate spi:self transactionFlowStateChanged:_state];
}
/**
 * The PIN pad server will reply to our PurchaseRequest with a PurchaseResponse.
 *
 * @param m Message
 */
- (void)handlePurchaseResponse:(SPIMessage *)m {
    NSLog(@"handlePurchaseResponse");
    
    if (self.state.flow != SPIFlowTransaction ||
        self.state.txFlowState.isFinished) {
        NSString *msg = [NSString stringWithFormat:@"Received purchase response but I was not waiting for one. %@", m.decryptedJson];
        SPILog(msg);
        return;
    }
    
    // TH-1A, TH-2A
    
    [self.state.txFlowState completed:m.successState
                             response:m
                                  msg:@"Purchase transaction ended."];
    // TH-6A, TH-6E
    
    [self.delegate spi:self transactionFlowStateChanged:self.state.copy];
}

/**
 * The PIN pad server will reply to our RefundRequest with a RefundResponse.
 *
 * @param m Message
 */
- (void)handleRefundResponse:(SPIMessage *)m {
    NSLog(@"handleRefundResponse");
    
    if (self.state.flow != SPIFlowTransaction ||
        self.state.txFlowState.isFinished) {
        SPILog(@"Received refund response but I was not waiting for one. %@", m.decryptedJson);
        return;
    }
    
    // TH-1A, TH-2A
    [self.state.txFlowState completed:m.successState
                             response:m
                                  msg:@"Refund transaction ended."];
    // TH-6A, TH-6E
    
    [self.delegate spi:self transactionFlowStateChanged:self.state];
}

/**
 * Handle the Settlement Response received from the PIN pad.
 *
 * @param m Message
 */
- (void)handleSettleResponse:(SPIMessage *)m {
    NSLog(@"handleSettleResponse");
    
    if (self.state.flow != SPIFlowTransaction ||
        self.state.txFlowState.isFinished) {
        SPILog(@"Received settle response but I was not waiting for one. %@", m.decryptedJson);
        return;
    }
    
    // TH-1A, TH-2A
    [self.state.txFlowState completed:m.successState
                             response:m
                                  msg:@"Settle transaction ended."];
    // TH-6A, TH-6E
    
    [self.delegate spi:self transactionFlowStateChanged:self.state];
}

/**
 * Sometimes we receive event type "error" from the server, such as when calling
 * cancel_transaction and there is no transaction in progress.
 *
 * @param m SPIMessage
 */
- (void)handleErrorEvent:(SPIMessage *)m {
    if (self.state.flow == SPIFlowTransaction &&
        !self.state.txFlowState.isFinished &&
        self.state.txFlowState.isAttemptingToCancel &&
        [m.error isEqualToString:@"NO_TRANSACTION"]) {
        // TH-2E
        SPILog(@"Was trying to cancel a transaction but there is nothing to cancel. Calling GLT to see what's up");
        [self callGetLastTransaction];
    } else {
        SPILog(@"Received error event but don't know what to do with it. %@", m.decryptedJson);
    }
}

/**
 * When the PIN pad returns to us what the last transaction was.
 *
 * @param m Message
 */
- (void)handleGetLastTransactionResponse:(SPIMessage *)m {
    NSLog(@"handleGetLastTransactionResponse");
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        SPITransactionFlowState *txState = self.state.txFlowState;
        
        if (self.state.flow != SPIFlowTransaction || txState.isFinished) {
            // We were not in the middle of a transaction, who cares?
            return;
        }
        
        // TH-4 We were in the middle of a transaction.
        // Let's attempt recovery. This is step 4 of transaction processing
        // handling
        SPILog(@"Got last transaction. Attempting recovery.");
        [txState gotGltResponse];
        
        SPIGetLastTransactionResponse *gltResponse =
        [[SPIGetLastTransactionResponse alloc] initWithMessage:m];
        if (!gltResponse.wasRetrievedSuccessfully) {
            if ([gltResponse isStillInProgress:txState.posRefId]) {
                // TH-4E - Operation In Progress
                if ([gltResponse isWaitingForSignatureResponse] && !txState.isAwaitingSignatureCheck) {
                    SPILog(
                           @"Eftpos is waiting for us to send it signature "
                           @"accept/decline, but we were not aware of this. The "
                           @"user can only really decline at this stage as there "
                           @"is no receipt to print for signing.");
                    
                    [weakSelf.state.txFlowState signatureRequired:[[SPISignatureRequired alloc]
                                                                   initWithPosRefId:txState.posRefId
                                                                   requestId:m.mid
                                                                   receiptToSign:@"MISSING RECEIPT\n DECLINE AND TRY AGAIN."]
                                                              msg:@"Recovered in Signature Required but we don't have receipt. You may Decline then Retry."];
                } else if ([gltResponse isWaitingForAuthCode] &&
                           !txState.isAwaitingPhoneForAuth) {
                    SPILog(
                           @"Eftpos is waiting for us to send it auth code, but "
                           @"we were not aware of this. We can only cancel the "
                           @"transaction at this stage as we don't have enough "
                           @"information to recover from this.");
                    
                    [weakSelf.state.txFlowState
                     phoneForAuthRequired:[[SPIPhoneForAuthRequired alloc]
                                           initWithPosRefId:txState.posRefId
                                           requestId:m.mid
                                           phoneNumber:@"UNKNOWN"
                                           merchantId:@"UNKNOWN"]
                     msg:@"Recovered mid Phone-For-Auth but don't have details. You may Cancel then Retry."];
                } else {
                    SPILog(@"Operation still in progress... stay waiting.");
                    // No need to publish txFlowStateChanged. Can return;
                    return;
                }
            } else {
                // TH-4X - Unexpected Error when recovering
                SPILog(@"Unexpected Response in Get Last Transaction during - Received posRefId:%@ error: %@", [gltResponse getPosRefId], m.error);
                [txState unknownCompleted:@"Unexpected error when recovering transaction status. Check EFTPOS."];
            }
        } else {
            if (txState.type == SPITransactionTypeGetLastTransaction) {
                // THIS WAS A PLAIN GET LAST TRANSACTION REQUEST, NOT FOR RECOVERY
                // PURPOSES.
                SPILog(@"Retrieved last transaction as asked directly by the user.");
                [gltResponse copyMerchantReceiptToCustomerReceipt];
                [txState completed:gltResponse.successState
                          response:m
                               msg:@"Last transaction retrieved"];
            } else {
                // TH-4A - Let's try to match the received last transaction against the current transaction
                SPIMessageSuccessState successState = [self gltMatch:gltResponse posRefId:txState.posRefId];
                if (successState == SPIMessageSuccessStateUnknown) {
                    // TH-4N: Didn't Match our transaction. Consider Unknown
                    // State.
                    SPILog(@"Did not match transaction.");
                    [txState unknownCompleted:@"Failed to recover transaction status. Check EFTPOS."];
                } else {
                    // TH-4Y: We Matched, transaction finished, let's update
                    // ourselves
                    [gltResponse copyMerchantReceiptToCustomerReceipt];
                    [txState completed:successState
                              response:m
                                   msg:@"Transaction ended."];
                }
            }
            
            [self.delegate spi:self transactionFlowStateChanged:self.state.copy];
        }
    });
}

- (SPIMessageSuccessState)gltMatch:(SPIGetLastTransactionResponse *)gltResponse
                      expectedType:(SPITransactionType)expectedType
                    expectedAmount:(NSInteger)expectedAmount
                       requestDate:(NSDate *)requestDate
                          posRefId:(NSString *)posRefId {
    return [self gltMatch:gltResponse posRefId:posRefId];
}

- (SPIMessageSuccessState)gltMatch:(SPIGetLastTransactionResponse *)gltResponse
                          posRefId:(NSString *)posRefId {
    SPILog(@"GLT CHECK: PosRefId: %@->%@}", posRefId,
           [gltResponse getPosRefId]);
    
    if (![posRefId isEqualToString:gltResponse.getPosRefId]) {
        return SPIMessageSuccessStateUnknown;
    }
    
    return gltResponse.getSuccessState;
}

- (void)transactionMonitoring {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        // SPILog(@"transactionMonitoring");
        
        BOOL needsPublishing = NO;
        SPITransactionFlowState *txState = weakSelf.state.txFlowState;
        
        if (weakSelf.state.flow == SPIFlowTransaction && !txState.isFinished) {
            SPITransactionFlowState *state = txState.copy;
            NSDate *now = [NSDate date];
            NSDate *cancel = [state.cancelAttemptTime
                              dateByAddingTimeInterval:maxWaitForCancelTx];
            
            if (state.isAttemptingToCancel &&
                [now compare:cancel] == NSOrderedDescending) {
                // TH-2T - too long since cancel attempt - Consider unknown
                SPILog(@"Been too long waiting for transaction to cancel.");
                [txState unknownCompleted:@"Waited long enough for cancel transaction result. Check EFTPOS. "];
                needsPublishing = YES;
                
            } else if (state.isRequestSent &&
                       [now compare:[state.lastStateRequestTime
                                     dateByAddingTimeInterval:
                                     checkOnTxFrequency]] ==
                       NSOrderedDescending) {
                
                // TH-1T, TH-4T - It's been a while since we received an update,
                // let's call a GLT
                SPILog(@"Checking on our transaction. Last we asked was at %@...",
                       state.lastStateRequestTime);
                [txState callingGlt];
                [weakSelf callGetLastTransaction];
            }
        }
        
        if (needsPublishing) {
            [weakSelf.delegate spi:weakSelf
       transactionFlowStateChanged:weakSelf.state];
        }
    });
}

#pragma mark - Internals for Connection Management

- (void)resetConnection {
    // Setup the Connection
    self.connection.delegate = nil;
    self.connection = [[SPIWebSocketConnection alloc] initWithDelegate:self];
}

#pragma mark - SPIConnectionDelegate

/**
 * This method will be called when the connection status changes.
 * You are encouraged to display a PIN pad connection indicator on the POS
 * screen.
 *
 * @param newConnectionState Connection state
 */
- (void)onSpiConnectionStatusChanged:(SPIConnectionState)newConnectionState {
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"onSpiConnectionStatusChanged %ld", (long)newConnectionState);
        
        switch (newConnectionState) {
            case SPIConnectionStateConnecting:
                SPILog(@"I'm connecting to the EFTPOS at %@...",
                       weakSelf.eftposAddress);
                break;
                
            case SPIConnectionStateConnected:
                
                if (weakSelf.state.flow == SPIFlowPairing) {
                    weakSelf.state.pairingFlowState.message =
                    @"Requesting to pair...";
                    [weakSelf.delegate spi:weakSelf
                   pairingFlowStateChanged:weakSelf.state];
                    SPIPairingRequest *pr = [SPIPairingHelper newPairRequest];
                    [weakSelf send:[pr toMessage]];
                } else {
                    SPILog(@"I'm connected to %@", weakSelf.eftposAddress);
                    weakSelf.spiMessageStamp.secrets = weakSelf.secrets;
                    [weakSelf startPeriodicPing];
                }
                
                break;
                
            case SPIConnectionStateDisconnected:
                SPILog(@"I'm disconnected to %@", weakSelf.eftposAddress);
                // Let's reset some lifecycle related state, ready for next connection
                weakSelf.mostRecentPingSent = nil;
                weakSelf.mostRecentPongReceived = nil;
                weakSelf.missedPongsCount = 0;
                [weakSelf stopPeriodPing];
                
                if (weakSelf.state.status != SPIStatusUnpaired) {
                    weakSelf.state.status = SPIStatusPairedConnecting;
                    [weakSelf.delegate spi:self statusChanged:weakSelf.state];
                    dispatch_async(self.queue, ^{
                        if (weakSelf.state.flow == SPIFlowTransaction &&
                            !weakSelf.state.pairingFlowState.isFinished) {
                            // we're in the middle of a transaction, just so you know!
                            // TH-1D
                            SPILog(@"Lost connection in the middle of a transaction...");
                        }
                    });
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                                   ^{
                                       if (weakSelf.connection == nil) {
                                           return;
                                       }
                                       SPILog(@"Will try to reconnect in 5s...");
                                       sleep(5);
                                       if (weakSelf.state.status != SPIStatusUnpaired) {
                                           [weakSelf.connection connect];
                                       }
                                   });
                    
                } else if (weakSelf.state.flow == SPIFlowPairing) {
                    SPILog(@"Lost connection during pairing.");
                    weakSelf.state.pairingFlowState.message = @"Could not connect to pair. Check network/EFTPOS and try again...";
                    [weakSelf onPairingFailed];
                    [self.delegate spi:self pairingFlowStateChanged:self.state];
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
    if (_pingTimer != nil) {
        [_pingTimer cancel];
        _pingTimer = nil;
    }
    _pingTimer = [[SPIGCDTimer alloc] initWithObject:self queue:"com.assemblypayments.ping"];
    
    [_pingTimer afterDelay:0
                    repeat:true
                     block:^(id self) {
                         if (!weakSelf.connection.isConnected || weakSelf.secrets == nil) {
                             dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                                            ^{
                                                [weakSelf.pingTimer cancel];
                                            });
                             return;
                         }
                         [self doPing];
                         sleep(pongTimeout);
                         if (weakSelf.mostRecentPingSent != nil &&
                             (weakSelf.mostRecentPongReceived == nil || weakSelf.mostRecentPongReceived.mid != weakSelf.mostRecentPingSent.mid)) {
                             weakSelf.missedPongsCount += 1;
                             SPILog(@"Eftpos didn't reply to my Ping. Missed Count: %i", weakSelf.missedPongsCount / missedPongsToDisconnect);
                             if (weakSelf.missedPongsCount < missedPongsToDisconnect) {
                                 SPILog(@"Trying another ping...");
                                 return;
                             }
                             // This means that we have reached missed pong limit.
                             // We consider this connection as broken.
                             // Let's Disconnect.
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
    __weak __typeof(&*self) weakSelf = self;
    NSLog(@"onReadyToTransact %lu, %d", (unsigned long)self.state.flow,
          (int)!self.state.txFlowState.isFinished);
    
    // So, we have just made a connection, pinged and logged in successfully.
    self.state.status = SPIStatusPairedConnected;
    [self.delegate spi:self statusChanged:self.state.copy];
    
    dispatch_async(self.queue, ^{
        if (self.state.flow == SPIFlowTransaction &&
            !self.state.txFlowState.isFinished) {
            
            if (self.state.txFlowState.isRequestSent) {
                // TH-3A - We've just reconnected and were in the middle of Tx.
                // Let's get the last transaction to check what we might have
                // missed out on.
                
                [self.state.txFlowState callingGlt];
                [self callGetLastTransaction];
            } else {
                // TH-3AR - We had not even sent the request yet. Let's do that
                // now
                [self send:self.state.txFlowState.request];
                [self.state.txFlowState sent:@"Sending Request Now..."];
                [self.delegate spi:self transactionFlowStateChanged:self.state];
            }
        } else {
            [weakSelf.spiPat PushPayAtTableConfig];
            SPILog(@"onReadyToTransact, we were NOT in the middle of a transaction. nothing to do.");
        }
    });
}

/**
 * When we disconnect, we should also stop the periodic ping.
 */
- (void)stopPeriodPing {
    NSLog(@"stopPeriodPing");
    // If we were already set up, clean up before restarting.
    [self.pingTimer cancel];
    [self.disconnectIfNeededSourceTimer cancel];
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
    
    // We need to maintain this time delta otherwise the server will not accept
    // our messages.
    self.spiMessageStamp.serverTimeDelta = m.serverTimeDelta;
    
    if (self.mostRecentPongReceived == nil) {
        // First pong received after a connection, and after the pairing process
        // is fully finalised.
        if (_state.status != SPIStatusUnpaired) {
            SPILog(@"First pong of connection and in paired state.");
            [self onReadyToTransact];
        } else {
            SPILog(@"First pong of connection but pairing process not finalised yet.");
        }
    }
    
    self.mostRecentPongReceived = m;
    SPILog(@"PongLatency:%i",
           [NSDate date].timeIntervalSince1970 - _mostRecentPingSentTime);
}

- (void)handleSettlementEnquiryResponse:(SPIMessage *)m {
    NSLog(@"handleSettlementEnquiryResponse");
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        if (weakSelf.state.flow != SPIFlowTransaction ||
            weakSelf.state.txFlowState.isFinished) {
            SPILog(@"Received Settlement Enquiry response but I was not waiting for one. %@", [m decryptedJson]);
            return;
        }
        // TH-1A, TH-2A
        [weakSelf.state.txFlowState completed:[m successState]
                                     response:m
                                          msg:@"Settlement Enquiry Ended."];
        // TH-6A, TH-6E
    });
    [weakSelf.delegate spi:self transactionFlowStateChanged:_state];
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

/**
 * Ask the PIN pad to tell us what the Most Recent Transaction was
 */
- (void)callGetLastTransaction {
    [self send:[[SPIGetLastTransactionRequest new] toMessage]];
}

/**
 *
 * Ask the PIN pad to initiate settlement
 */
- (void)settle {
    NSLog(@"settle");
    
    SPISettleRequest *settleRequest = [[SPISettleRequest alloc]
                                       initWithSettleId:[SPIRequestIdHelper idForString:@"settle"]];
    SPILog(@"Asking EFTPOS to execute Settlement...");
    [self.connection
     send:[[settleRequest toMessage]
           toJson:self.spiMessageStamp]]; // Send it to the PIN pad server
}

/**
 * <summary>
 * This method will be called whenever we receive a message from the Connection
 * </summary>
 * @param message Message
 */
- (void)onSpiMessageReceived:(NSString *)message {
    
    __weak __typeof(&*self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        // First we parse the incoming message
        SPIMessage *m = [SPIMessage fromJson:message secrets:weakSelf.secrets];
        
        NSString *eventName = m.eventName;
        
        NSLog(@"Received: %@", m.decryptedJson);
        
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
            // includes cancel purchases
            [weakSelf handlePurchaseResponse:m];
            
        } else if ([eventName isEqualToString:SPIRefundResponseKey]) {
            [weakSelf handleRefundResponse:m];
            
        } else if ([eventName isEqualToString:SPICashoutOnlyResponseKey]) {
            [weakSelf handleCashoutOnlyResponse:m];
            
        } else if ([eventName isEqualToString:SPIMotoPurchaseResponseKey]) {
            [weakSelf handleMotoPurchaseResponse:m];
            
        } else if ([eventName isEqualToString:SPISignatureRequiredKey]) {
            [weakSelf handleSignatureRequired:m];
            
        } else if ([eventName isEqualToString:SPIAuthCodeRequiredKey]) {
            [weakSelf handleAuthCodeRequired:m];
            
        } else if ([eventName isEqualToString:SPIGetLastTransactionResponseKey]) {
            [weakSelf handleGetLastTransactionResponse:m];
            
        } else if ([eventName isEqualToString:SPISettleResponseKey]) {
            [weakSelf handleSettleResponse:m];
            
        } else if ([eventName isEqualToString:SPISettlementEnquiryResponseKey]) {
            [weakSelf handleSettlementEnquiryResponse:m];
            
        } else if ([eventName isEqualToString:SPIPingKey]) {
            [weakSelf handleIncomingPing:m];
            
        } else if ([eventName isEqualToString:SPIPongKey]) {
            [weakSelf handleIncomingPong:m];
            
        } else if ([eventName isEqualToString:SPIKeyRollRequestKey]) {
            [weakSelf handleKeyRollingRequest:m];
            
        } else if ([eventName isEqualToString:SPIPayAtTableGetTableConfigKey]) {
            if (weakSelf.spiPat == nil) {
                [self
                 send:[SPIPayAtTableConfig
                       featureDisableMessage:[SPIRequestIdHelper
                                              idForString:@"patconf"]]];
                return;
            }
            [weakSelf.spiPat handleGetTableConfig:m];
            
        } else if ([eventName isEqualToString:SPIPayAtTableGetBillDetailsKey]) {
            [weakSelf.spiPat handleGetBillDetailsRequest:m];
            
        } else if ([eventName isEqualToString:SPIPayAtTableBillPaymentKey]) {
            [weakSelf.spiPat handleBillPaymentAdvice:m];
        } else if ([eventName isEqualToString:SPIInvalidHmacSignature]) {
            SPILog(@"I could not verify message from EFTPOS. You might have to un-pair EFTPOS and then reconnect.");
            
        } else if ([eventName isEqualToString:SPIEventError]) {
            SPILog(@"ERROR!!: '%@', %@", m.eventName, m.data);
            [weakSelf handleErrorEvent:m];
            
        } else {
            SPILog(@"I don't understand event:'%@', %@. Perhaps I have not implemented it yet.", m.eventName, m.data);
        }
    });
}

- (void)didReceiveError:(NSError *)error {
    dispatch_async(self.queue, ^{
        SPILog(@"Received WS error: %@", error);
    });
}

@end

@implementation SPIConfig
- (void)addReceiptConfig:(NSMutableDictionary *)data {
    if (_promptForCustomerCopyOnEftpos) {
        [data setObject:[NSNumber numberWithBool:_promptForCustomerCopyOnEftpos]
                 forKey:@"prompt_for_customer_copy"];
    }
    if (_signatureFlowOnEftpos) {
        [data setObject:[NSNumber numberWithBool:_signatureFlowOnEftpos]
                 forKey:@"print_for_signature_required_transactions"];
    }
}
@end
