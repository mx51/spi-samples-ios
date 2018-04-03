//
//  SPIPairingHelper.m
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-26.
//  Copyright © 2017 Assembly Payments. All rights reserved.
//

#import "SPIPairingHelper.h"

#import "JKBigInteger.h"
#import "SPIPairing.h"
#import "NSString+Crypto.h"
#import "SPICrypto.h"
#import "SPIDiffieHellman.h"
#import "SPISecrets.h"
#import "NSData+Crypto.h"

@implementation SPIPublicKeyAndSecret
- (id)initWithMyPublicKey:(NSString *)myPublicKey secretKey:(NSString *)sharedSecretKey {
    self = [super init];
    
    if (self) {
        _myPublicKey     = [myPublicKey copy];
        _sharedSecretKey = [sharedSecretKey copy];
    }
    
    return self;
}

@end

@implementation SPIPairingHelper

+ (SPIPairingRequest *)newPairRequest {
    return [SPIPairingRequest new];
}

+ (SPISecretsAndKeyResponse *)generateSecretsAndKeyResponseForKeyRequest:(SPIKeyRequest *)keyRequest {
    SPIPublicKeyAndSecret *encPubAndSec = [self calculateMyPublicKeyAndSecret:keyRequest.aenc];
    NSString             *benc         = encPubAndSec.myPublicKey;
    NSString             *senc         = encPubAndSec.sharedSecretKey;
    
    SPIPublicKeyAndSecret *hmacPubAndSec = [self calculateMyPublicKeyAndSecret:keyRequest.ahmac];
    NSString             *bhmac         = hmacPubAndSec.myPublicKey;
    NSString             *shmac         = hmacPubAndSec.sharedSecretKey;
    
    SPISecrets     *secrets     = [[SPISecrets alloc] initWithEncKey:senc hmacKey:shmac];
    SPIKeyResponse *keyResponse = [[SPIKeyResponse alloc] initWithRequestId:keyRequest.requestId benc:benc bhmac:bhmac];
    
    return [[SPISecretsAndKeyResponse alloc] initWithSecrets:secrets keyResponse:keyResponse];
}

+ (SPIPublicKeyAndSecret *)calculateMyPublicKeyAndSecret:(NSString *)theirPublicKey {
    //NSLog(@"calculateMyPublicKeyAndSecret %@", theirPublicKey);
    
    // SPI uses the 2048-bit MODP Group as the shared constants for the DH algorithm
    // https://tools.ietf.org/html/rfc3526#section-3
    JKBigInteger *modp2048P = [[JKBigInteger alloc] initWithString:@"32317006071311007300338913926423828248817941241140239112842009751400741706634354222619689417363569347117901737909704191754605873209195028853758986185622153212175412514901774520270235796078236248884246189477587641105928646099411723245426622522193230540919037680524235519125679715870117001058055877651038861847280257976054903569732561526167081339361799541336476559160368317896729073178384589680639671900977202194168647225871031411336429319536193471636533209717077448227988588565369208645296636077250268955505928362751121174096972998068410554359584866583291642136218231078990999448652468262416972035911852507045361090559"];
    JKBigInteger *modp2048G = [[JKBigInteger alloc] initWithString:@"2"];
    
    JKBigInteger *theirPublicBI = [self spiAHexStringToBigIntegerForHexStringA:theirPublicKey];
    JKBigInteger *myPrivateBI   = [SPIDiffieHellman randomPrivateKey:modp2048P];
    JKBigInteger *myPublicBI    = [SPIDiffieHellman publicKeyWithPrimeP:modp2048P primeG:modp2048G privateKey:myPrivateBI];
    JKBigInteger *secretBI      = [SPIDiffieHellman secretWithPrimeP:modp2048P theirPublicKey:theirPublicBI yourPrivateKey:myPrivateBI];
    
    NSString *myPublic = [[myPublicBI stringValueWithRadix:16] uppercaseString];
    NSString *secret   = [self dhSecretToSPISecret:secretBI];
    
    //NSLog(@"theirPublicBI %@", theirPublicBI);
    //NSLog(@"myPrivateBI %@",   myPrivateBI);
    //NSLog(@"myPublicBI %@",    myPublicBI);
    //
    //NSLog(@"myPublic %@",      myPublic);
    //NSLog(@"secret %@",        secret);
    
    return [[SPIPublicKeyAndSecret alloc] initWithMyPublicKey:myPublic secretKey:secret];
}

+ (JKBigInteger *)spiAHexStringToBigIntegerForHexStringA:(NSString *)hexStringA {
    return [[JKBigInteger alloc] initWithString:[NSString stringWithFormat:@"00%@", hexStringA] andRadix:16];
}

+ (NSString *)dhSecretToSPISecret:(JKBigInteger *)secretBI {
    NSString *mySecretHex = [[secretBI stringValueWithRadix:16] uppercaseString];
    
    if (mySecretHex.length == 513) {
        // happens in .net haven't seen it in iOS
        mySecretHex = [mySecretHex substringFromIndex:1];
    }
    
    if (mySecretHex.length < 512) {
        int length = (int)(512 - mySecretHex.length);
        
        NSString *format  = [NSString stringWithFormat:@"%%0%dd", (int)length];
        NSString *padding = [NSString stringWithFormat:format, 0];
        mySecretHex = [NSString stringWithFormat:@"%@%@", padding, mySecretHex];
    }
    
    return [[[mySecretHex dataFromHexEncoding] SHA256] hexString];
}

@end
