//
//  FriendViewCell.h
//  kaya_meet
//
//  Created by Jun Li on 12/25/10.
//

#import <UIKit/UIKit.h>
//#import "KYMeet.h"

@interface FriendViewCell : UITableViewCell {
	UILabel *nameLabel;
	UIImageView *friendImageView;
}

@property(nonatomic,retain)UILabel *nameLabel;
@property(nonatomic,retain)UIImageView *friendImageView;

@end
