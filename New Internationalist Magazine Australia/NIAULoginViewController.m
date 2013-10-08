//
//  NIAULoginViewController.m
//  New Internationalist Magazine Australia
//
//  Created by Simon Loffler on 8/10/13.
//  Copyright (c) 2013 New Internationalist Australia. All rights reserved.
//

#import "NIAULoginViewController.h"
#import <SSKeychain.h>

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
    
    NSLog(@"TODO: do rails login here.");
 
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
    NSLog(@"TODO: Do stuff.");
    
    // delete all entries from keychain (probably a bad idea, we are testing)
    [[SSKeychain accountsForService:@"NIWebApp"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [SSKeychain deletePasswordForService:obj[@"svce"] account:obj[@"acct"]];
    }];
    
    [SSKeychain setPassword:self.password.text forService:@"NIWebApp" account:self.username.text];
    
    if([self.password.text isEqual:@"topseekret"]) {
        UIAlertView *theAlert = [[UIAlertView alloc] initWithTitle:@"Warning"
                                                           message:[NSString   stringWithFormat:@"%@ is a dumb password", self.password.text]
                                                          delegate:self
                                                 cancelButtonTitle:@"I'm sorry"
                                                 otherButtonTitles:nil];
        [theAlert show];
    }
}

@end
