//
//  Copyright © 2018 PubNative. All rights reserved.
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

#import "PNLiteDemoConsentViewController.h"
#import "PNLiteUserDataManager.h"

@interface PNLiteDemoConsentViewController ()
@property (weak, nonatomic) IBOutlet UIButton *privacyPolicyURLButton;
@property (weak, nonatomic) IBOutlet UIButton *vendorListURLButton;


@end

@implementation PNLiteDemoConsentViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (IBAction)pnOwnedTouchUpInside:(UIButton *)sender
{
    /*
    // This would be the normal implementation for a regular publisher.
    // We remove this condition here for testing purposes
    if ([[PNLiteUserDataManager sharedInstance] shouldAskConsent]) {
        [[PNLiteUserDataManager sharedInstance] showConsentRequestScreen];
    } else {
        NSLog(@"Consent has already been answered. If you want to try again please clear your app cache");
    }
    */
    self.privacyPolicyURLButton.hidden = YES;
    self.vendorListURLButton.hidden = YES;
    [[PNLiteUserDataManager sharedInstance] showConsentRequestScreen];
}

- (IBAction)publisherOwnedTouchUpInside:(UIButton *)sender
{
    [self.privacyPolicyURLButton setTitle:[[PNLiteUserDataManager sharedInstance] privacyPolicyLink] forState:UIControlStateNormal];
    [self.vendorListURLButton setTitle:[[PNLiteUserDataManager sharedInstance] vendorListLink] forState:UIControlStateNormal];
    self.privacyPolicyURLButton.hidden = NO;
    self.vendorListURLButton.hidden = NO;
}

- (IBAction)acceptConsentTouchUpInside:(UIButton *)sender
{
    [[PNLiteUserDataManager sharedInstance] grantConsent];
}

- (IBAction)rejectConsentTouchUpInside:(UIButton *)sender
{
    [[PNLiteUserDataManager sharedInstance] denyConsent];
}

- (IBAction)privacyPolicyURLTouchUpInside:(UIButton *)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:sender.titleLabel.text]];
}

- (IBAction)vendorListURLTouchUpInside:(UIButton *)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:sender.titleLabel.text]];
}

@end
