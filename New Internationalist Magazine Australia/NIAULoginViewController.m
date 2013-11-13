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

@interface NIAULoginViewController ()

@end

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
    
    
    NSArray *accounts = [SSKeychain accountsForService:@"NIWebApp"];
    if([accounts count]>0) {
        NSDictionary *dict = accounts[0];
        self.username.text = dict[@"acct"];
        self.password.text = [SSKeychain passwordForService:dict[@"svce"] account:dict[@"acct"]];
    } else {
        self.username.text = @"coolname";
        self.password.text = @"topseekret";
    }
    
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)loginButtonTapped:(id)sender
{
    
    NSString *username = self.username.text;
    NSString *password = self.password.text;
    
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
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:[NSURL URLWithString:[NSString stringWithFormat:@"users/sign_in.json?password=%@&username=%@", password, username] relativeToURL:[NSURL URLWithString:SITE_URL]]];
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        NSData *postData = [[NSString stringWithFormat:@"user[login]=%@&user[password]=%@",username,password] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody:postData];
        
        
        NSError *error;
        NSHTTPURLResponse *response;
//        NSData *responseData =
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:SITE_URL]];
        int statusCode = [response statusCode];
        if(statusCode >= 200 && statusCode < 300) {
            [[[UIAlertView alloc] initWithTitle:@"Success" message:@"Excellent, you've successfully logged in!" delegate:self cancelButtonTitle:@"Thanks!" otherButtonTitles:nil] show];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Uh oh, did you get your username or password wrong?" delegate:self cancelButtonTitle:@"Try again." otherButtonTitles:nil] show];
        }
        
        
        
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Sorry, there was a problem with the keychain: %@", error] delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil] show];
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

@end
