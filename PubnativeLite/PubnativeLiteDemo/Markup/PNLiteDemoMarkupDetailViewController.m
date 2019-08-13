//
//  Copyright © 2019 PubNative. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "PNLiteDemoMarkupDetailViewController.h"
#import <HyBid/HyBid.h>

@interface PNLiteDemoMarkupDetailViewController () <HyBidMRAIDViewDelegate, HyBidMRAIDServiceDelegate>

@property (weak, nonatomic) IBOutlet UIView *markupContainer;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *markupContainerWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *markupContainerHeightConstraint;
@property (nonatomic, strong) HyBidMRAIDServiceProvider *serviceProvider;
@property (nonatomic, retain) HyBidMRAIDView *mraidView;

@end

@implementation PNLiteDemoMarkupDetailViewController

- (void)dealloc {
    self.markup = nil;
    self.serviceProvider = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    switch ([self.markup.placement integerValue]) {
        case 0: {
            self.markupContainerWidthConstraint.constant = 320;
            self.markupContainerHeightConstraint.constant = 50;
            break;
        }
        case 1: {
            self.markupContainerWidthConstraint.constant = 300;
            self.markupContainerHeightConstraint.constant = 250;
            break;
        }
        case 2: {
            self.markupContainerWidthConstraint.constant = 728;
            self.markupContainerHeightConstraint.constant = 90;
            break;
        }
        default:
            break;
    }
    [self renderMarkup];
}

- (void)renderMarkup {
    self.serviceProvider = [[HyBidMRAIDServiceProvider alloc] init];
    self.mraidView = [[HyBidMRAIDView alloc] initWithFrame:CGRectMake(0, 0, self.markupContainerWidthConstraint.constant, self.markupContainerHeightConstraint.constant)
                                              withHtmlData:self.markup.text
                                               withBaseURL:nil
                                         supportedFeatures:@[PNLiteMRAIDSupportsSMS, PNLiteMRAIDSupportsTel, PNLiteMRAIDSupportsCalendar, PNLiteMRAIDSupportsStorePicture, PNLiteMRAIDSupportsInlineVideo]
                                             isInterstital:NO
                                                  delegate:self
                                           serviceDelegate:self
                                        rootViewController:self
                                               contentInfo:nil];
    
    [self.markupContainer addSubview:self.mraidView];
}

- (IBAction)dismissButtonTouchUpInside:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark HyBidMRAIDViewDelegate

- (void)mraidViewAdReady:(HyBidMRAIDView *)mraidView {
    [HyBidLogger debugLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:@"MRAID did load."];
}

- (void)mraidViewAdFailed:(HyBidMRAIDView *)mraidView {
    [HyBidLogger errorLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:@"MRAID View failed."];
}

- (void)mraidViewWillExpand:(HyBidMRAIDView *)mraidView {
    [HyBidLogger debugLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:@"MRAID will expand."];
}

- (void)mraidViewDidClose:(HyBidMRAIDView *)mraidView {
    [HyBidLogger debugLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:@"MRAID did close."];
}

- (void)mraidViewNavigate:(HyBidMRAIDView *)mraidView withURL:(NSURL *)url {
    [HyBidLogger debugLogFromClass:NSStringFromClass([self class]) fromMethod:NSStringFromSelector(_cmd) withMessage:[NSString stringWithFormat:@"MRAID navigate with URL:%@",url]];
    [self.serviceProvider openBrowser:url.absoluteString];
}

- (BOOL)mraidViewShouldResize:(HyBidMRAIDView *)mraidView toPosition:(CGRect)position allowOffscreen:(BOOL)allowOffscreen {
    return NO;
}

#pragma mark HyBidMRAIDServiceDelegate

- (void)mraidServiceCallNumberWithUrlString:(NSString *)urlString {
    [self.serviceProvider callNumber:urlString];
}

- (void)mraidServiceSendSMSWithUrlString:(NSString *)urlString {
    [self.serviceProvider sendSMS:urlString];
}

- (void)mraidServiceCreateCalendarEventWithEventJSON:(NSString *)eventJSON {
    [self.serviceProvider createEvent:eventJSON];
}

- (void)mraidServiceOpenBrowserWithUrlString:(NSString *)urlString {
    [self.serviceProvider openBrowser:urlString];
}

- (void)mraidServicePlayVideoWithUrlString:(NSString *)urlString {
    [self.serviceProvider playVideo:urlString];
}

- (void)mraidServiceStorePictureWithUrlString:(NSString *)urlString {
    [self.serviceProvider storePicture:urlString];
}
@end
