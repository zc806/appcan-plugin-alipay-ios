//
//  EUExAliPay.h
//  EUExAliPay
//
//  Created by xurigan on 14/11/10.
//  Copyright (c) 2014年 com.zywx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EUExBase.h"
#import "EUExBaseDefine.h"
#import "EUtility.h"
#import "AlixLibService.h"
#import "PartnerConfig.h"
#import "DataSigner.h"
#import "AlixPayResult.h"
#import "DataVerifier.h"
#import "AlixPayOrder.h"


#define UEX_CPAYSUCCESS			0
#define UEX_CPAYING             1
#define UEX_CPAYFAILED			2
#define UEX_CPAYPLUGINERROR		3

@interface EUExAliPay : EUExBase

- (void)uexOnPayWithStatus:(int)inStatus des:(NSString *)inDes;
- (void)parseURL:(NSURL *)url application:(UIApplication *)application;

@end
