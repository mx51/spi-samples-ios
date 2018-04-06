//
//  SPIClient.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-28.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIClient.h"
#import "SPIModels.h"

#import "SPIConnection.h"
#import "SPIWebSocketConnection.h"
#import "SPIMessage.h"
#import "SPIPairingHelper.h"
#import "SPIMessage.h"
#import "SPIPairing.h"
#import "SPIPingHelper.h"
#import "SPILogin.h"
#import "SPIPurchase.h"
#import "SPIKeyRollingHelper.h"
#import "SPIRequestIdHelper.h"
#import "SPISettleRequest.h"
#import "NSString+Util.h"
#import "SPILogger.h"
#import "NSObject+Util.h"
#import "SPIGCDTimer.h"

@interface SPIClient () <SPIConnectionDelegate>

// The current status of this SPI instance. Unpaired, PairedConnecting or PairedConnected.
@property (nonatomic, strong) SPIState *state;

@property (nonatomic, strong) id <SPIConnection> connection;

@property (nonatomic, strong) SPIMessageStamp *spiMessageStamp;
@property (nonatomic, strong) SPISecrets      *secrets;

@property (nonatomic, strong) SPIGCDTimer *pingTimer;
@property (nonatomic, strong) SPIGCDTimer *disconnectIfNeededSourceTimer;
@property (nonatomic, strong) SPIGCDTimer *transactionMonitoringTimer;
@property (nonatomic, strong) SPIGCDTimer *tryToReconnectTimer;

@property (nonatomic, strong) SPIMessage *mostRecentPingSent;
@property (nonatomic, strong) SPIMessage *mostRecentPongReceived;
@property (nonatomic, assign) NSInteger  missedPongsCount;

@property (nonatomic, strong) SPILoginResponse     *mostRecentLoginResponse;
@property (nonatomic, strong) SPISignatureRequired *mostRecentSignatureRequiredReceived;

@property (nonatomic, assign)  BOOL readyToTransact;

@property (nonatomic, assign)  BOOL started;

@property (nonatomic, strong) dispatch_queue_t queue;

@end

static NSTimeInterval txMonitorCheckFrequency        = 1; // How often do we check on the tx state from our tx monitoring thread
static NSTimeInterval checkOnTxFrequency             = 20; // How often do we proactively check on the tx status by calling get_last_transaction
static NSTimeInterval maxWaitForCancelTx             = 10; // How long do we wait for cancel to return before giving up completely.
static NSTimeInterval tryToReconnectTime             = 5; // How long do we wait before attempting a re-connection
static NSTimeInterval txServerAdjustmentTimeInterval = -5; // Adjust server time

static NSTimeInterval pongTimeout   = 5;  // How long do we wait for a pong to come back
static NSTimeInterval pingFrequency = 18; // How often we send pings
static NSInteger missedPongsToDisconnect = 2; // How many missed pongs before disconnecting

@implementation SPIClient

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _queue = dispatch_queue_create("au.com.assemblypayments", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0));
        
        _pingTimer                     = [[SPIGCDTimer alloc] initWithObject:self queue:"au.com.assemblypayments.ping"];
        _disconnectIfNeededSourceTimer = [[SPIGCDTimer alloc] initWithObject:self queue:"au.com.assemblypayments.disconnect"];
        _transactionMonitoringTimer    = [[SPIGCDTimer alloc] initWithObject:self queue:"au.com.assemblypayments.txMonitor"];
        _tryToReconnectTimer           = [[SPIGCDTimer alloc] initWithObject:self queue:"au.com.assemblypayments.tryToReconnect"];
        
        _state = [SPIState new];
    }
    
    return self;
}

- (void)dealloc {
    _delegate = nil;
    [_connection disconnect];
    _connection.delegate = nil;
    _connection          = nil;
    [_pingTimer cancel];
    [_disconnectIfNeededSourceTimer cancel];
    [_transactionMonitoringTimer cancel];
    [_tryToReconnectTimer cancel];
}

- (BOOL)start {
    if (self.started) {return false;}
    
    NSLog(@"start");
    
    if (self.posId) {
        // Our stamp for signing outgoing messages
        self.spiMessageStamp = [[SPIMessageStamp alloc] initWithPosId:self.posId secrets:self.secrets serverTimeDelta:0];
    }
    
    // Setup the Connection
    self.connection = [[SPIWebSocketConnection alloc] initWithDelegate:self];
    [self.connection setUrl:self.eftposAddress];
    
    [self.transactionMonitoringTimer afterDelay:txMonitorCheckFrequency repeat:YES block:^(id self) {
        [self transactionMonitoring];
    }];
    
    self.state.flow = SPIFlowIdle;
    self.started = true;
    
    if (self.secrets && self.eftposAddress) {
        NSLog(@"setup with secrets");
        
        self.state.status = SPIStatusPairedConnecting;
        [self.delegate spi:self statusChanged:self.state.copy];
        [self connect];
        return NO;
    } else {
        NSLog(@"setup with NO secrets");
        
        self.state.status = SPIStatusUnpaired;
        [self.delegate spi:self statusChanged:self.state.copy];
        return YES;
    }
}

- (void)setSecretEncKey:(NSString *)encKey hmacKey:(NSString *)hmacKey {
    self.secrets = [[SPISecrets alloc] initWithEncKey:encKey hmacKey:hmacKey];
}

- (BOOL)updatePosId:(NSString *)posId {
    if (self.state.status != SPIStatusUnpaired) return NO;
    
    _posId                     = posId.copy;
    self.spiMessageStamp.posId = posId;
    return YES;
}

- (BOOL)updateEftposAddress:(NSString *)eftposAddress {
    if (self.state.status != SPIStatusUnpaired) return NO;
    
    self.eftposAddress = eftposAddress;
    return YES;
}

- (void)ackFlowEndedAndBackToIdle:(SPICompletionState)completion {
    NSLog(@"ackFlowEndedAndBackToIdle");
    
    dispatch_async(self.queue, ^{
        if (self.state.flow == SPIFlowIdle) return completion(YES, self.state.copy); // already idle
        
        if ((self.state.flow == SPIFlowPairing && self.state.pairingFlowState.isFinished)
            || (self.state.flow == SPIFlowTransaction && self.state.txFlowState.isFinished)) {
            self.state.flow = SPIFlowIdle;
            
            return completion(YES, self.state.copy);
            
        }
        
        completion(NO, self.state.copy);
    });
}

#pragma mark -  Pairing Flow Methods

- (void)pair {
    NSLog(@"pair");
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        if (weakSelf.state.status != SPIStatusUnpaired) return;
        
        SPIPairingFlowState *currentPairingFlowState = [SPIPairingFlowState new];
        currentPairingFlowState.message = @"Connecting...";
        currentPairingFlowState.confirmationCode = @"";
        currentPairingFlowState.isAwaitingCheckFromEftpos = NO;
        currentPairingFlowState.isAwaitingCheckFromPos = NO;
        
        weakSelf.state.flow = SPIFlowPairing;
        weakSelf.state.pairingFlowState = currentPairingFlowState;
        
        [weakSelf.delegate spi:weakSelf pairingFlowStateChanged:weakSelf.state.copy];
        [weakSelf.connection connect];
    });
    
}

- (void)pairingConfirmCode {
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"pairingConfirmCode isAwaitingCheckFromEftpos=%@", @(weakSelf.state.pairingFlowState.isAwaitingCheckFromEftpos));
        
        if (!weakSelf.state.pairingFlowState.isAwaitingCheckFromPos) {
            // We weren't expecting this
            return;
        }
        
        weakSelf.state.pairingFlowState.isAwaitingCheckFromPos = NO;
        
        if (weakSelf.state.pairingFlowState.isAwaitingCheckFromEftpos) {
            // But we are still waiting for confirmation from EFTPOS side.
            weakSelf.state.pairingFlowState.message = [NSString stringWithFormat:@"Click YES on EFTPOS if code is: %@", weakSelf.state.pairingFlowState.confirmationCode];
            [weakSelf.delegate spi:weakSelf pairingFlowStateChanged:weakSelf.state.copy];
        } else {
            NSLog(@"pairedReady");
            // Already confirmed from EFTPOS - So all good now. We're Paired also from the POS perspective.
            weakSelf.state.pairingFlowState.message = @"Pairing successful";
            [weakSelf onPairingSuccess];
            [weakSelf onReadyToTransact];
        }
    });
}

- (void)pairingCancel {
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"pairingCancel");
        
        if (weakSelf.state.flow != SPIFlowPairing || weakSelf.state.pairingFlowState.isFinished) {
            return;
        }
        
        [weakSelf onPairingFailed:@"Pairing cancelled"];
    });
}

- (void)unpair {
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"unpair");
        
        if (weakSelf.state.status == SPIStatusUnpaired) return;
        
        if (weakSelf.state.flow != SPIFlowIdle) return;
        
        weakSelf.state.status = SPIStatusUnpaired;
        weakSelf.state.pairingFlowState = nil;
        weakSelf.state.txFlowState = nil;
        [weakSelf.delegate spi:self statusChanged:weakSelf.state.copy];
        
        [weakSelf.connection disconnect];
        weakSelf.secrets = nil;
        weakSelf.spiMessageStamp.secrets = nil;
        [weakSelf.delegate spi:weakSelf secretsChanged:nil state:weakSelf.state];
    });
}

#pragma mark - Transactions

- (void)initiatePurchaseTx:(NSString *)pid amountCents:(NSInteger)amountCents completion:(SPICompletionTxResult)completion {
    
    SPILog(@"initiatePurchaseTx");
    
    if (self.state.status == SPIStatusUnpaired) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        return;
    } else if (self.state.flow != SPIFlowIdle) {
        completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
        return;
    }
    
    SPIPurchaseRequest *purchase        = [[SPIPurchaseRequest alloc] initWithPurchaseId:pid amountCents:amountCents];
    SPIMessage         *purchaseMessage = [purchase toMessage];
    
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        weakSelf.state.flow = SPIFlowTransaction;
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:pid
                                                                             type:SPITransactionTypePurchase
                                                                      amountCents:amountCents
                                                                          message:purchaseMessage
                                                                              msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to make payment request for $%.2f", amountCents / 100.0]];
        
        if ([weakSelf send:purchaseMessage]) {
            [weakSelf.state.txFlowState sent:[NSString stringWithFormat:@"Asked EFTPOS to accept payment for $%.2f", amountCents / 100.0]];
        }
        
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Purchase initiated"]);
        
        [weakSelf.delegate spi:self transactionFlowStateChanged:weakSelf.state.copy];
    });
}

- (void)initiateRefundTx:(NSString *)pid amountCents:(NSInteger)amountCents completion:(SPICompletionTxResult)completion {
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        SPILog(@"initiateRefundTx");
        
        if (weakSelf.state.status == SPIStatusUnpaired) return completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        
        if (weakSelf.state.flow != SPIFlowIdle) return completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
        
        SPIRefundRequest *refund = [[SPIRefundRequest alloc] initWithRefundId:pid amountCents:amountCents];
        
        weakSelf.state.flow = SPIFlowTransaction;
        SPIMessage *purchaseMessage = [refund toMessage];
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:pid
                                                                             type:SPITransactionTypeRefund
                                                                      amountCents:amountCents
                                                                          message:purchaseMessage
                                                                              msg:[NSString stringWithFormat:@"Waiting for EFTPOS connection to make refund request for $%.2f", amountCents / 100.0]];
        
        if ([weakSelf send:purchaseMessage]) {
            [weakSelf.state.txFlowState sent:[NSString stringWithFormat:@"Asked EFTPOS to refund $%.2f", amountCents / 100.0]];
        }
        
        [weakSelf.delegate spi:weakSelf transactionFlowStateChanged:weakSelf.state.copy];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Refund initiated"]);
    });
}

- (void)acceptSignature:(BOOL)accepted {
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        SPILog(@"acceptSignature");
        
        if (weakSelf.state.flow != SPIFlowTransaction || weakSelf.state.txFlowState.isFinished || !weakSelf.state.txFlowState.isAwaitingSignatureCheck) {
            SPILog(@"Asked to accept signature but I was not waiting for one.");
            return;
        }
        
        [weakSelf.state.txFlowState signatureResponded:accepted ? @"Accepting signature..." : @"Declining signature..."];
        
        NSString *sigReqMsgId = self.state.txFlowState.signatureRequiredMessage.requestId;
        SPIMessage *msg = accepted
        ? [[[SPISignatureAccept alloc] initWithSignatureRequiredRequestId:sigReqMsgId] toMessage] :
        [[[SPISignatureDecline alloc] initWithSignatureRequiredRequestId:sigReqMsgId] toMessage];
        
        [weakSelf send:msg];
        
        [weakSelf.delegate spi:weakSelf transactionFlowStateChanged:weakSelf.state.copy];
        
    });
}

- (void)cancelTransaction {
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        SPILog(@"cancelTransaction");
        
        if (weakSelf.state.flow != SPIFlowTransaction || weakSelf.state.txFlowState.isFinished) {
            SPILog(@"Asked to cancel transaction but I was not in the middle of one.");
            return;
        }
        
        // TH-1C, TH-3C - Merchant pressed cancel
        if (weakSelf.state.txFlowState.isRequestSent) {
            SPICancelTransactionRequest *cancelReq = [SPICancelTransactionRequest new];
            [weakSelf.state.txFlowState cancelling:@"Attempting to cancel transaction..."];
            [weakSelf send:[cancelReq toMessage]];
        } else {
            // We Had Not Even Sent Request Yet. Consider as known failed.
            [weakSelf.state.txFlowState failed:nil msg:@"Transaction cancelled. Request had not even been sent yet."];
        }
        
        [weakSelf.delegate spi:weakSelf transactionFlowStateChanged:weakSelf.state.copy];
    });
}

- (void)initiateSettleTx:(NSString *)pid completion:(SPICompletionTxResult)completion {
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        if (weakSelf.state.status == SPIStatusUnpaired) return completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not paired"]);
        
        if (weakSelf.state.flow != SPIFlowIdle) return completion([[SPIInitiateTxResult alloc] initWithTxResult:NO message:@"Not idle"]);
        
        SPISettleRequest *settleRequest = [[SPISettleRequest alloc] initWithSettleId:[SPIRequestIdHelper idForString:@"settle"]];
        
        weakSelf.state.flow = SPIFlowTransaction;
        SPIMessage *settleMessage = [settleRequest toMessage];
        weakSelf.state.txFlowState = [[SPITransactionFlowState alloc] initWithTid:pid
                                                                             type:SPITransactionTypeSettle
                                                                      amountCents:0
                                                                          message:settleMessage
                                                                              msg:@"Waiting for EFTPOS connection to make a settle request"];
        
        if ([weakSelf send:settleMessage]) {
            [weakSelf.state.txFlowState sent:@"Asked EFTPOS to settle."];
        }
        
        [weakSelf.delegate spi:weakSelf transactionFlowStateChanged:weakSelf.state.copy];
        completion([[SPIInitiateTxResult alloc] initWithTxResult:YES message:@"Settle initiated"]);
    });
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
    
    if (_posId.length == 0) {return; }
    
    self.spiMessageStamp = [[SPIMessageStamp alloc] initWithPosId:posId secrets:nil serverTimeDelta:0];
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
 * Handling the 2nd interaction of the pairing process, i.e. an incoming KeyRequest.
 *
 * @param m Message
 */
- (void)handleKeyRequest:(SPIMessage *)m {
    SPILog(@"handleKeyRequest");
    
    self.state.pairingFlowState.message = @"Negotiating pairing...";
    [self.delegate spi:self pairingFlowStateChanged:self.state.copy];
    
    // Use the helper. It takes the incoming request, and generates the secrets and the response.
    SPISecretsAndKeyResponse *result = [SPIPairingHelper generateSecretsAndKeyResponseForKeyRequest:[[SPIKeyRequest alloc] initWithMessage:m]];
    self.secrets                 = result.secrets; // we now have secrets, although pairing is not fully finished yet.
    self.spiMessageStamp.secrets = self.secrets; // updating our stamp with the secrets so can encrypt messages later.
    [self send:[result.keyResponse toMessage]]; // send the key_response, i.e. interaction 3 of pairing.
}

/**
 *
 * Handling the 4th interaction of the pairing process i.e. an incoming KeyCheck.
 *
 * @param m Message
 */
- (void)handleKeyCheck:(SPIMessage *)m {
    SPILog(@"handleKeyCheck");
    
    SPIKeyCheck *keyCheck = [[SPIKeyCheck alloc] initWithMessage:m];
    self.state.pairingFlowState.confirmationCode          = keyCheck.confirmationCode;
    self.state.pairingFlowState.isAwaitingCheckFromEftpos = YES;
    self.state.pairingFlowState.isAwaitingCheckFromPos    = YES;
    self.state.pairingFlowState.message                   = [NSString stringWithFormat:@"Confirm that the following Code:\n\n%@\n\n is showing on the terminal", keyCheck.confirmationCode];
    [self.delegate spi:self pairingFlowStateChanged:self.state.copy];
}

/**
 * Handling the 5th and final interaction of the pairing process, i.e. an incoming PairResponse
 *
 * @param m Message
 */
- (void)handlePairResponse:(SPIMessage *)m {
    NSLog(@"handlePairResponse");
    
    SPIPairResponse *pairResponse = [[SPIPairResponse alloc] initWithMessage:m];
    self.state.pairingFlowState.isAwaitingCheckFromEftpos = NO;
    
    if (pairResponse.isSuccess) {
        if (self.state.pairingFlowState.isAwaitingCheckFromPos) {
            // Still Waiting for User to say yes on POS
            self.state.pairingFlowState.message = [NSString stringWithFormat:@"Confirm that the following Code:\n\n%@\n\n is what the EFTPOS showed", self.state.pairingFlowState.confirmationCode];
            [self.delegate spi:self pairingFlowStateChanged:self.state.copy];
        } else {
            self.state.pairingFlowState.message = @"Pairing successful";
            [self onPairingSuccess];
        }
        
        // I need to ping/login even if the pos user has not said yes yet,
        // because otherwise within 5 seconds connectiong will be dropped by eftpos.
        [self startPeriodicPing];
    } else {
        [self onPairingFailed:@"Pairing failed"];
    }
}

- (void)onPairingSuccess {
    NSLog(@"onPairingSuccess");
    
    self.state.pairingFlowState.isSuccessful = YES;
    self.state.pairingFlowState.isFinished   = YES;
    self.state.pairingFlowState.message      = @"Pairing successful!";
    self.state.status                        = SPIStatusPairedConnected;
    [self.delegate spi:self secretsChanged:self.secrets state:self.state];
    [self.delegate spi:self pairingFlowStateChanged:self.state.copy];
}

- (void)onPairingFailed:(NSString *)msg {
    NSLog(@"onPairingFailed");
    
    self.secrets                 = nil;
    self.spiMessageStamp.secrets = nil;
    [self.connection disconnect];
    
    self.state.status = SPIStatusUnpaired;
    [self.delegate spi:self statusChanged:self.state.copy];
    
    self.state.pairingFlowState.message                = msg;
    self.state.pairingFlowState.isFinished             = YES;
    self.state.pairingFlowState.isSuccessful           = NO;
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
    SPIKeyRollingResult *krRes = [SPIKeyRollingHelper performKeyRollingWithMessage:m currentSecrets:self.secrets];
    self.secrets                 = krRes.secrets; // and update our secrets with them
    self.spiMessageStamp.secrets = self.secrets;  // and our stamp
    [self send:krRes.keyRollingConfirmation];
    [self.delegate spi:self secretsChanged:self.secrets state:self.state];
    
    //ylee
    self.mostRecentPingSent = nil;
    [self startPeriodicPing];
}

#pragma mark - Transaction Management

/**
 * The PIN pad server will send us this message when a customer signature is reqired.
 * We need to ask the customer to sign the incoming receipt.
 * And then tell the pinpad whether the signature is ok or not.
 *
 * @param m Message
 */
- (void)handleSignatureRequired:(SPIMessage *)m {
    NSLog(@"handleSignatureRequired");
    
    if (self.state.flow != SPIFlowTransaction || self.state.txFlowState.isFinished) {
        SPILog(@"Received signature required but I was not waiting for one. %@", m.decryptedJson);
        return;
    }
    
    [self.state.txFlowState signatureRequired:[[SPISignatureRequired alloc] initWithMessage:m] msg:@"Ask customer to sign the receipt"];
    
    [self.delegate spi:self transactionFlowStateChanged:self.state.copy];
}

/**
 * The PIN pad server will reply to our PurchaseRequest with a PurchaseResponse.
 *
 * @param m Message
 */
- (void)handlePurchaseResponse:(SPIMessage *)m {
    NSLog(@"handlePurchaseResponse");
    
    if (self.state.flow != SPIFlowTransaction || self.state.txFlowState.isFinished) {
        SPILog(@"Received purchase response but I was not waiting for one. %@", m.decryptedJson);
        return;
    }
    
    // TH-1A, TH-2A
    
    [self.state.txFlowState completed:m.successState response:m msg:@"Purchase transaction ended."];
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
    
    if (self.state.flow != SPIFlowTransaction || self.state.txFlowState.isFinished) {
        SPILog(@"Received refund response but I was not waiting for one. %@", m.decryptedJson);
        return;
    }
    
    // TH-1A, TH-2A
    [self.state.txFlowState completed:m.successState response:m msg:@"Refund transaction ended."];
    // TH-6A, TH-6E
    
    [self.delegate spi:self transactionFlowStateChanged:self.state.copy];
}

/**
 * Handle the Settlement Response received from the PIN pad.
 *
 * @param m Message
 */
- (void)handleSettleResponse:(SPIMessage *)m {
    NSLog(@"handleSettleResponse");
    
    if (self.state.flow != SPIFlowTransaction || self.state.txFlowState.isFinished) {
        SPILog(@"Received settle response but I was not waiting for one. %@", m.decryptedJson);
        return;
    }
    
    // TH-1A, TH-2A
    [self.state.txFlowState completed:m.successState response:m msg:@"Settle transaction ended."];
    // TH-6A, TH-6E
    
    [self.delegate spi:self transactionFlowStateChanged:self.state.copy];
}

/**
 * Sometimes we receive event type "error" from the server, such as when calling cancel_transaction and there is no transaction in progress.
 *
 * @param m SPIMessage
 */
- (void)handleErrorEvent:(SPIMessage *)m {
    if (self.state.flow == SPIFlowTransaction
        && !self.state.txFlowState.isFinished
        && self.state.txFlowState.isAttemptingToCancel
        && [m.error isEqualToString:@"NO_TRANSACTION"]) {
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
    
    SPITransactionFlowState *txState = self.state.txFlowState;
    
    if (self.state.flow != SPIFlowTransaction || txState.isFinished) {
        // We were not in the middle of a transaction, who cares?
        return;
    }
    
    // TH-4 We were in the middle of a transaction.
    // Let's attempt recovery. This is step 4 of transaction processing handling
    SPILog(@"Got last transaction. Attempting recovery.");
    [txState gotGltResponse];
    
    SPIGetLastTransactionResponse *gtlResponse = [[SPIGetLastTransactionResponse alloc] initWithMessage:m];
    
    NSDate *reqServerDate = [txState.requestDate dateByAddingTimeInterval:self.spiMessageStamp.serverTimeDelta];
    reqServerDate = [reqServerDate dateByAddingTimeInterval:txServerAdjustmentTimeInterval];
    //NSDate *gtlBankDate = gtlResponse.bankDate;
    
    if (!gtlResponse.wasRetrievedSuccessfully) {
        if (gtlResponse.wasOperationInProgressError) {
            // TH-4E - Operation In Progress
            SPILog(@"Operation still in progress... Stay waiting.");
        } else {
            // TH-4X - Unexpected Error when recovering
            SPILog(@"Unexpected error in get last transaction response during transaction recovery: %@", m.error);
            [txState unknownCompleted:@"Unexpected error when recovering transaction status. Check EFTPOS."];
        }
    } else {
        // TH-4A - Let's try to match the received last transaction against the current transaction
        NSDate *reqServerDate = [txState.requestDate dateByAddingTimeInterval:self.spiMessageStamp.serverTimeDelta];
        reqServerDate = [reqServerDate dateByAddingTimeInterval:txServerAdjustmentTimeInterval];
        NSDate *gtlBankDate = gtlResponse.bankDate;
        
        SPILog(@"Amount: %ld->%ld, Date: %@->%@", txState.amountCents, gtlResponse.getTransactionAmount, reqServerDate, gtlBankDate);
        
        if (txState.amountCents != gtlResponse.getTransactionAmount || [reqServerDate compare:gtlBankDate] == NSOrderedDescending) {
            // TH-4N: Didn't Match our transaction. Consider Unknown State.
            SPILog(@"Did not match transaction.");
            [txState unknownCompleted:@"Failed to recover transaction status. Check EFTPOS."];
        } else {
            // TH-4Y: We Matched, transaction finished, let's update ourselves
            [gtlResponse copyMerchantReceiptToCustomerReceipt];
            [txState completed:m.successState response:m msg:@"Transaction ended."];
        }
        
        [self.delegate spi:self transactionFlowStateChanged:self.state.copy];
    }
}

- (void)transactionMonitoring {
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        //SPILog(@"transactionMonitoring");
        
        BOOL needsPublishing = NO;
        SPITransactionFlowState *txState = weakSelf.state.txFlowState;
        
        if (weakSelf.state.flow == SPIFlowTransaction && !txState.isFinished) {
            SPITransactionFlowState *state = txState.copy;
            NSDate *now = [NSDate date];
            NSDate *cancel = [state.cancelAttemptTime dateByAddingTimeInterval:maxWaitForCancelTx];
            
            if (state.isAttemptingToCancel && [now compare:cancel] == NSOrderedDescending) {
                // TH-2T - too long since cancel attempt - Consider unknown
                SPILog(@"Been too long waiting for transaction to cancel.");
                [txState unknownCompleted:@"Waited long enough for cancel transaction result. Check EFTPOS. "];
                needsPublishing = YES;
                
            } else if (state.isRequestSent
                       && [now compare:[state.lastStateRequestTime dateByAddingTimeInterval:checkOnTxFrequency]] == NSOrderedDescending) {
                
                // TH-1T, TH-4T - It's been a while since we received an update, let's call a GLT
                SPILog(@"Checking on our transaction. Last we asked was at %@...", state.lastStateRequestTime);
                [txState callingGlt];
                [weakSelf callGetLastTransaction];
            }
        }
        
        if (needsPublishing) {
            [weakSelf.delegate spi:weakSelf transactionFlowStateChanged:weakSelf.state.copy];
        }
    });
}

#pragma mark - Internals for Connection Management

- (void)resetConnection {
    // Setup the Connection
    self.connection.delegate = nil;
    self.connection          = [[SPIWebSocketConnection alloc] initWithDelegate:self];
}

#pragma mark - SPIConnectionDelegate

/**
 * This method will be called when the connection status changes.
 * You are encouraged to display a PIN pad connection indicator on the POS screen.
 *
 * @param newConnectionState Connection state
 */
- (void)onSpiConnectionStatusChanged:(SPIConnectionState)newConnectionState {
    __weak __typeof(& *self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        NSLog(@"onSpiConnectionStatusChanged %ld", (long)newConnectionState);
        
        switch (newConnectionState) {
            case SPIConnectionStateConnecting:
                SPILog(@"I'm connecting to the EFTPOS at %@...", weakSelf.eftposAddress);
                break;
                
            case SPIConnectionStateConnected:
                
                if (weakSelf.state.flow == SPIFlowPairing) {
                    weakSelf.state.pairingFlowState.message = @"Requesting to pair...";
                    [weakSelf.delegate spi:weakSelf pairingFlowStateChanged:weakSelf.state.copy];
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
                weakSelf.mostRecentLoginResponse = nil;
                weakSelf.readyToTransact = NO;
                [weakSelf stopPeriodPing];
                
                if (weakSelf.state.status != SPIStatusUnpaired) {
                    
                    weakSelf.state.status = SPIStatusPairedConnecting;
                    [weakSelf.delegate spi:weakSelf statusChanged:weakSelf.state.copy];
                    
                    if (weakSelf.state.flow == SPIFlowTransaction) {
                        // we're in the middle of a transaction, just so you know!
                        // TH-1D
                        SPILog(@"Lost connection in the middle of a transaction...");
                    }
                    
                    SPILog(@"Will try to reconnect soon...");
                    
                    [weakSelf.tryToReconnectTimer cancel];
                    [weakSelf.tryToReconnectTimer afterDelay:tryToReconnectTime repeat:NO block:^(id self) {
                        SPILog(@"tryToReconnect");
                        
                        if (weakSelf.state.status != SPIStatusUnpaired) {
                            SPILog(@"Try to reconnect now");
                            [weakSelf.connection connect];
                        }
                    }];
                    
                } else if (weakSelf.state.flow == SPIFlowPairing) {
                    SPILog(@"Lost connection during pairing.");
                    
                    if (!weakSelf.state.pairingFlowState.isFinished) {
                        [weakSelf onPairingFailed:@"Could not connect to pair. Check network/EFTPOS and try again..."];
                    }
                }
                
                break;
        }
    });
}

#pragma mark - Ping

/**
 * This is an important piece of the puzzle. It's a background thread that periodically
 * sends pings to the server. If it doesn't receive pongs, it considers the connection as broken
 * so it disconnects.
 */
- (void)startPeriodicPing {
    SPILog(@"startPeriodicPing");
    self.missedPongsCount = 0;
    
    // If we were already set up, clean up before restarting.
    [self stopPeriodPing];
    
    //There can be no delay onces started or else will get error!!
    [self doPing];
}

/**
 * We call this ourselves as soon as we're ready to transact with the PIN pad after a connection is established.
 * This function is effectively called after we received the first Login Response from the PIN pad.
 */
- (void)onReadyToTransact {
    NSLog(@"onReadyToTransact %lu, %d", (unsigned long)self.state.flow, (int)!self.state.txFlowState.isFinished);
    
    // So, we have just made a connection, pinged and logged in successfully.
    self.state.status = SPIStatusPairedConnected;
    [self.delegate spi:self statusChanged:self.state.copy];
    
    if (self.state.flow == SPIFlowTransaction && !self.state.txFlowState.isFinished) {
        
        if (self.state.txFlowState.isRequestSent) {
            // TH-3A - We've just reconnected and were in the middle of Tx.
            // Let's get the last transaction to check what we might have missed out on.
            
            [self.state.txFlowState callingGlt];
            [self callGetLastTransaction];
        } else {
            // TH-3AR - We had not even sent the request yet. Let's do that now
            [self send:self.state.txFlowState.request];
            [self.state.txFlowState sent:[NSString stringWithFormat:@"Asked EFTPOS to accept payment for %0.2f", self.state.txFlowState.amountCents / 100.0]];
            [self.delegate spi:self transactionFlowStateChanged:self.state.copy];
        }
    } else {
        NSLog(@"onReadyToTransact, we were NOT in the middle of a transaction. nothing to do.");
    }
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
    
    [self.disconnectIfNeededSourceTimer afterDelay:pongTimeout repeat:NO block:^(SPIClient *self) {
        NSLog(@"pingDisconnectIfNeeded");
        
        if (self.mostRecentPingSent != nil
            && (self.mostRecentPongReceived == nil || ![self.mostRecentPongReceived.mid isEqualToString:self.mostRecentPingSent.mid])) {
            
            self.missedPongsCount += 1;
            SPILog(@"EFTPOS didn't reply to my ping. Missed count: %d/%d", self.missedPongsCount, missedPongsToDisconnect);
            
            if (self.missedPongsCount < missedPongsToDisconnect) {
                SPILog(@"Trying another ping...");
                [self.pingTimer afterDelay:(1) repeat:NO block:^(SPIClient *self) {
                    [self doPing];
                }];
                return;
            }
            // This means that we have not received a pong for our most recent ping.
            // We consider this connection as broken.
            // Let's disconnect.
            SPILog(@"Disconnecting...");
            [self.connection disconnect];
            
        } else {
            self.missedPongsCount = 0;
            if (self.connection.isConnected && self.secrets != nil) {
                [self.pingTimer afterDelay:(pingFrequency - pongTimeout) repeat:NO block:^(SPIClient *self) {
                    [self doPing];
                }];
            }
        }
    }];
}

/**
 * Received a pong from the server.
 *
 * @param m Message
 */
- (void)handleIncomingPong:(SPIMessage *)m {
    NSLog(@"handleIncomingPong");
    
    // We need to maintain this time delta otherwise the server will not accept our messages.
    self.spiMessageStamp.serverTimeDelta = m.serverTimeDelta;
    
    if (self.mostRecentLoginResponse == nil
        || [self.mostRecentLoginResponse expiringSoon:self.spiMessageStamp.serverTimeDelta]) {
        // We have not logged in yet, or login expiring soon.
        [self login];
    }
    
    self.mostRecentPongReceived = m;
}

/**
 * Login is a mute thing but is required.
 */
- (void)login {
    NSLog(@"login");
    SPILoginRequest *lr = [SPILoginRequest new];
    [self send:[lr toMessage]];
}

/**
 * When the server replied to our LoginRequest with a LoginResponse, we take note of it.
 *
 * @param m Message
 */
- (void)handleLoginResponse:(SPIMessage *)m {
    NSLog(@"handleLoginResponse");
    
    SPILoginResponse *lr = [[SPILoginResponse alloc] initWithMessage:m];
    
    if (lr.isSuccess) {
        self.mostRecentLoginResponse = lr;
        
        if (!self.readyToTransact) {
            // We are finally ready to make transactions.
            // Let's notify ourselves so we can take some actions.
            self.readyToTransact = YES;
            SPILog(@"Logged in successfully. Expires: %@", lr.expires);
            
            if (self.state.status != SPIStatusUnpaired) {
                [self onReadyToTransact];
            }
        } else {
            SPILog(@"I have just refreshed my login. Now Expires: %@", lr.expires);
        }
    } else {
        SPILog(@"Logged in failure.");
        [self.connection disconnect];
    }
}

/**
 *
 * The server will also send us pings. We need to reply with a pong so it doesn't disconnect us.
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
 * Ask the PIN pad to tell us what the Most Recent Transaction was
 */
- (void)getLastTransaction {
    NSLog(@"getLastTransaction");
    
    // Create a GetLastTransactionRequest.
    SPIGetLastTransactionRequest *gltRequest = [SPIGetLastTransactionRequest new];
    SPILog(@"\nAsking EFTPOS to tell me what the most recent transaction was...");
    [self.connection send:[[gltRequest toMessage] toJson:self.spiMessageStamp]]; // Send it to the PIN pad server
}

/**
 *
 * Ask the PIN pad to initiate settlement
 */
- (void)settle {
    NSLog(@"settle");
    
    SPISettleRequest *settleRequest = [[SPISettleRequest alloc] initWithSettleId:[SPIRequestIdHelper idForString:@"settle"]];
    SPILog(@"Asking EFTPOS to execute Settlement...");
    [self.connection send:[[settleRequest toMessage] toJson:self.spiMessageStamp]]; // Send it to the PIN pad server
}

/**
 * <summary>
 * This method will be called whenever we receive a message from the Connection
 * </summary>
 * @param message Message
 */
- (void)onSpiMessageReceived:(NSString *)message {
    
    __weak __typeof(& *self) weakSelf = self;
    
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
            
        } else if ([eventName isEqualToString:SPILoginResponseKey]) {
            [weakSelf handleLoginResponse:m];
            
        } else if ([eventName isEqualToString:SPIPurchaseResponseKey]) {
            // includes cancel purchases
            [weakSelf handlePurchaseResponse:m];
            
        } else if ([eventName isEqualToString:SPIRefundResponseKey]) {
            [weakSelf handleRefundResponse:m];
            
        } else if ([eventName isEqualToString:SPISignatureRequiredKey]) {
            [weakSelf handleSignatureRequired:m];
            
        } else if ([eventName isEqualToString:SPIGetLastTransactionResponseKey]) {
            [weakSelf handleGetLastTransactionResponse:m];
            
        } else if ([eventName isEqualToString:SPISettleResponseKey]) {
            [weakSelf handleSettleResponse:m];
            
        } else if ([eventName isEqualToString:SPIPingKey]) {
            [weakSelf handleIncomingPing:m];
            
        } else if ([eventName isEqualToString:SPIPongKey]) {
            [weakSelf handleIncomingPong:m];
            
        } else if ([eventName isEqualToString:SPIKeyRollRequestKey]) {
            [weakSelf handleKeyRollingRequest:m];
            
        } else if ([eventName isEqualToString:SPIInvalidHmacSignature]) {
            SPILog(@"I could not verify message from EFTPOS. You might have to un-pair EFTPOS and then reconnect.");
            
        } else if ([eventName isEqualToString:SPIEventError]) {
            SPILog(@"ERROR!!: '%@', %@", m.eventName, m.data);
            
            // One reason for error is eftpos was unpaired, but pos is using old secrets
            // in this case maybe the delegate could reset the secret and try pairing?
            //
            // ie.
            // socket WebSocket closed [1005], (null), wasClean=1
            // "error_detail" = "Missing event";
            // "error_reason" = "MISSING_ARGUMENTS";
            // success = 0;
            
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
