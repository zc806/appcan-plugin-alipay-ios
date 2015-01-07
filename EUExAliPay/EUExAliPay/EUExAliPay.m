//
//  EUExAliPay.m
//  EUExAliPay
//
//  Created by xurigan on 14/11/10.
//  Copyright (c) 2014年 com.zywx. All rights reserved.
//

#import "EUExAliPay.h"

@interface EUExAliPay()

@property (nonatomic, retain) PartnerConfig * partnerConfig;
@property (nonatomic, retain) NSMutableDictionary * productDic;
@property (nonatomic, copy)   NSString * cbStr;

@end

@implementation EUExAliPay

-(id)initWithBrwView:(EBrowserView *)eInBrwView {
    if (self=[super initWithBrwView:eInBrwView]) {
        self.productDic = [NSMutableDictionary dictionary];
        _partnerConfig = [[PartnerConfig alloc]init];
    }
    return self;
}

-(void)dealloc{
    [self clean];
    [super dealloc];
}

-(void)clean{
    if (_cbStr) {
        _cbStr = nil;
    }
    if (_partnerConfig) {
        [_partnerConfig release];
        _partnerConfig = nil;
    }
}

-(void)setPayInfo:(NSMutableArray *)inArguments{
    
    if (![inArguments isKindOfClass:[NSMutableArray class]] || [inArguments count] < 4) {
        
        return;
        
    }
    
    NSString * partnerID = [inArguments objectAtIndex:0];
    NSString * sellerID = [inArguments objectAtIndex:1];
    NSString * partnerPrivKey = [inArguments objectAtIndex:2];
    NSString * alipayPubKey = [inArguments objectAtIndex:3];
    NSString * notifyUrl = nil;
    if ([inArguments count] == 5) {
        notifyUrl = [inArguments objectAtIndex:4];
    }
    
 
    
    //设置appschame
    NSString *appScheme = nil;
    NSArray *scharray = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleURLTypes"];
    if ([scharray count]>0) {
        NSDictionary *subDict = [scharray objectAtIndex:0];
        if ([subDict count]>0) {
            NSArray *urlArray = [subDict objectForKey:@"CFBundleURLSchemes"];
            if ([urlArray count]>0) {
                appScheme = [urlArray objectAtIndex:0];
            }
        }
    }
    
    [self.partnerConfig setPartnerID:partnerID];
    [self.partnerConfig setSellerID:sellerID];
    [self.partnerConfig setAlipayPubKey:alipayPubKey];
    [self.partnerConfig setPartnerPrivKey:partnerPrivKey];
    [self.partnerConfig setNotifyUrl:notifyUrl];
    [self.partnerConfig setAppScheme:appScheme];
}

-(void)pay:(NSMutableArray *)inArguments{
    NSString * tradeNO = [inArguments objectAtIndex:0];
    NSString * productName = [inArguments objectAtIndex:1];
    NSString * productDescription = [inArguments objectAtIndex:2];
    NSString * amount = [inArguments objectAtIndex:3];
    
    [self.productDic setObject:tradeNO forKey:@"tradeNO"];
    [self.productDic setObject:productName forKey:@"productName"];
    [self.productDic setObject:productDescription forKey:@"productDescription"];
    [self.productDic setObject:amount forKey:@"amount"];
    
    NSString *appScheme = self.partnerConfig.appScheme;
    NSString* orderInfo = [self getOrderInfo];
    NSString* signedStr = [self doRsa:orderInfo];
    NSString *orderString = [NSString stringWithFormat:@"%@&sign=\"%@\"&sign_type=\"%@\"",
                             orderInfo, signedStr, @"RSA"];
    [AlixLibService payOrder:orderString AndScheme:appScheme seletor:@selector(paymentResult:) target:self];
}

-(NSString *)getOrderInfo {
    AlixPayOrder *order = [[AlixPayOrder alloc] init];
    order.partner = self.partnerConfig.partnerID;
    order.seller = self.partnerConfig.sellerID;
    
    order.tradeNO = [self.productDic objectForKey:@"tradeNO"];
    order.productName = [self.productDic objectForKey:@"productName"];
    order.productDescription = [self.productDic objectForKey:@"productDescription"];
    order.amount = [self.productDic objectForKey:@"amount"];
    order.notifyURL =  self.partnerConfig.notifyUrl;
    
    return [order description];
}

-(NSString *)doRsa:(NSString *)orderInfo {
    id<DataSigner> signer;
    signer = CreateRSADataSigner(self.partnerConfig.partnerPrivKey);
    NSString *signedString = [signer signString:orderInfo];
    return signedString;
}

-(void)paymentResult:(NSString *)resultd {
    AlixPayResult* result = [[[AlixPayResult alloc] initWithString:resultd] autorelease];
    if (result) {
        if (result.statusCode == 9000) {
            NSString* key = self.partnerConfig.alipayPubKey;
            id<DataVerifier> verifier;
            verifier = CreateRSADataVerifier(key);
            if ([verifier verifyString:result.resultString withSign:result.signString]) {
                self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYSUCCESS,result.statusMessage];
            }
        } else {
            self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYPLUGINERROR,result.statusMessage];
        }
    } else {
        self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYFAILED,result.statusMessage];
    }
    [self performSelector:@selector(delayCB) withObject:self afterDelay:1.0];
    
}

-(void)uexOnPayWithStatus:(int)inStatus des:(NSString *)inDes{
    inDes =[inDes stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *jsStr = [NSString stringWithFormat:@"if(uexAliPay.onStatus!=null){uexAliPay.onStatus(%d,\'%@\')}",inStatus,inDes];
    [meBrwView stringByEvaluatingJavaScriptFromString:jsStr];
}

- (void)parseURL:(NSURL *)url application:(UIApplication *)application {
    AlixPayResult *result = [self handleOpenURL:url];
    self.cbStr = nil;
    if (result) {
        if (result.statusCode == 9000) {
            
            NSString * publicKey = self.partnerConfig.alipayPubKey;
            
            if (publicKey==nil) {
                
                self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexPay.onStatus",@"uexPay.onStatus",UEX_CPAYSUCCESS,@"订单可能未支付成功,请联系支付宝公司进行确认"];
                
            } else {
                
                id<DataVerifier> verifier = CreateRSADataVerifier([NSString stringWithString:publicKey]);
                if ([verifier verifyString:result.resultString withSign:result.signString]) {
                    self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYSUCCESS,result.statusMessage];
                } else {
                    self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYPLUGINERROR,result.statusMessage];
                }
            }
        } else {
            self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYFAILED,result.statusMessage];
        }
    }
    [self performSelector:@selector(delayCB) withObject:self afterDelay:1.0];
}

-(void)delayCB {
    [meBrwView stringByEvaluatingJavaScriptFromString:self.cbStr];
}

- (AlixPayResult *)handleOpenURL:(NSURL *)url {
    AlixPayResult * result = nil;
    if (url != nil && [[url host] compare:@"safepay"] == 0) {
        result = [self resultFromURL:url];
    }
    return result;
}

- (AlixPayResult *)resultFromURL:(NSURL *)url {
    NSString * query = [[url query] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [[[AlixPayResult alloc] initWithString:query] autorelease];
}

@end
