//
//  NIAULoginViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 8/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAULoginViewController.h"
#import <SSKeychain.h>
#import "local.h"
#import "Reachability.h"

@interface NIAULoginViewController ()

@end

NSString *LoginSuccessfulNotification = @"LoginSuccessful";
NSString *LoginUnsuccessfulNotification = @"LoginUnsuccessful";

@implementation NIAULoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.title = @"Log in";
    
    // Draw the nice gradient background
    [NIAUHelper drawGradientInView:self.view];
    
    NSArray *accounts = [SSKeychain accountsForService:@"NIWebApp"];
    if([accounts count]>0) {
        NSDictionary *dict = accounts[0];
        self.username.text = dict[@"acct"];
        self.password.text = [SSKeychain passwordForService:dict[@"svce"] account:dict[@"acct"]];
    } else {
        self.username.text = @"username";
        self.password.text = @"password";
    }
    
    // Register for keyboard notifications
    [self registerForKeyboardNotifications];
    
    // Dismiss keyboard on background tap
    UITapGestureRecognizer *backgroundTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:backgroundTap];
    
    // Add observer for the user changing the text size
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    
    [self sendGoogleAnalyticsStats];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)sendGoogleAnalyticsStats
{
    // Setup Google Analytics
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName
                                       value:@"Log in"];
    
    // Send the screen view.
    [[GAI sharedInstance].defaultTracker
     send:[[GAIDictionaryBuilder createAppView] build]];
}

- (void)dismissKeyboard
{
    [self.username resignFirstResponder];
    [self.password resignFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)loginButtonTapped:(id)sender
{    
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus netStatus = [reachability currentReachabilityStatus];
    
    if (netStatus == NotReachable) {
        // Ask them to turn on wifi or get internet access.
        [[[UIAlertView alloc] initWithTitle:@"Internet access?" message:@"It doesn't seem like you have internet access, turn it on to login." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
    } else {
        // Get the details from keychain
        NSString *username = self.username.text;
        NSString *password = self.password.text;
        
        // URLencode the strings so they don't break with & symbols. Thanks Terry M!
        NSString *usernameEncoded = [NIAUHelper URLEncodedString:username];
        NSString *passwordEncoded = [NIAUHelper URLEncodedString:password];
        
        NSError *error;
        if ([SSKeychain setPassword:password forService:@"NIWebApp" account:username error:&error]) {
            
    //        [[[UIAlertView alloc] initWithTitle:@"Password saved" message:@"Your password has been successfully saved" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];

            // delete all other entries from keychain (maybe a bad idea, but we are testing)
            [[SSKeychain accountsForService:@"NIWebApp"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSString *acct = obj[@"acct"];
                if(![acct isEqualToString:username]) {
                    [SSKeychain deletePasswordForService:obj[@"svce"] account:obj[@"acct"]];
                }
            }];
            
            // Delete old cookies
            NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            for (NSHTTPCookie *cookie in cookieStorage.cookies) {
                if ([cookie.domain isEqualToString:[[NSURL URLWithString:SITE_URL] host]]) {
                    NSLog(@"Deleting old cookie: %@", cookie);
                    [cookieStorage deleteCookie:cookie];
                }
            }
            
            // Try logging in to Rails.
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
            [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"users/sign_in.json?username=%@", usernameEncoded] relativeToURL:[NSURL URLWithString:SITE_URL]]];
            [request setHTTPMethod:@"POST"];
            [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            NSData *postData = [[NSString stringWithFormat:@"user[login]=%@&user[password]=%@",usernameEncoded,passwordEncoded] dataUsingEncoding:NSUTF8StringEncoding];
            NSString *postLength = [NSString stringWithFormat:@"%d", (int)[postData length]];
            [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
            [request setHTTPBody:postData];
            
            NSError *error;
            NSHTTPURLResponse *response;
    //        NSData *responseData =
            [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    //        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
            int statusCode = (int)[response statusCode];
            if(statusCode >= 200 && statusCode < 300) {
                // Send successful login notification
                [[NSNotificationCenter defaultCenter] postNotificationName:LoginSuccessfulNotification object:nil];
                [[[UIAlertView alloc] initWithTitle:@"Success" message:@"Excellent, you've successfully logged in!" delegate:self cancelButtonTitle:@"Thanks!" otherButtonTitles:nil] show];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:LoginUnsuccessfulNotification object:nil];
                [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Uh oh, did you get your username or password wrong?" delegate:self cancelButtonTitle:@"Try again." otherButtonTitles:nil] show];
            }
        
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Sorry, there was a problem with the keychain: %@", error] delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil] show];
        }
    }
}

- (IBAction)signupButtonTapped:(id)sender
{
    // Nothing to do..
}

#pragma mark -
#pragma mark Keyboard Delegate

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    // When return button is tapped, move to next field or act as if the user pressed login
    if (textField == self.username) {
        [textField resignFirstResponder];
        [self.password becomeFirstResponder];
        return NO;
    } else {
        [textField resignFirstResponder];
        [self loginButtonTapped:textField];
        return YES;
    }
}

- (void)keyboardWasShown: (NSNotification *)notification
{
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    NSDictionary* info = [notification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;

    if (orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight) {
        // move the textfield up.
        [UIView animateWithDuration:0.3 animations:^{
            CGRect newRect = self.view.frame;
            if (IS_IPAD()) {
                newRect.origin.y -= ((kbSize.width / 2) - 60.);
            } else {
                newRect.origin.y -= (kbSize.width - 60.);
            }
            self.view.frame = newRect;
        }];
    }
}

- (void)keyboardWillBeHidden: (NSNotification *)notification
{
    if (self.view.frame.origin.y < 0) {
        [UIView animateWithDuration:0.3 animations:^{
            CGRect newRect = self.view.frame;
            newRect.origin.y = 0.0;
            self.view.frame = newRect;
        }];
    }
}

#pragma mark -
#pragma mark Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"signupWebview"]) {

        NIAUWebsiteViewController *websiteViewController = [segue destinationViewController];
        NSURLRequest *railsSignup = [NSURLRequest requestWithURL:[NSURL URLWithString: @"https://digital.newint.com.au/users/sign_up"]
                                                     cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                 timeoutInterval:60.0];
        websiteViewController.linkToLoad = railsSignup;
    }
}

#pragma mark -
#pragma mark AlertView delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
    
    if ([buttonTitle isEqualToString:@"Thanks!"]) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Dynamic Text

- (void)preferredContentSizeChanged:(NSNotification *)notification
{
    NSLog(@"Notification received for text change!");
    
    self.username.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.password.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.loginButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.signupButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    
    [self.username setNeedsDisplay];
    [self.password setNeedsDisplay];
    [self.loginButton setNeedsDisplay];
}

@end
