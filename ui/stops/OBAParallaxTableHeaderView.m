//
//  OBAParallaxTableHeaderView.m
//  org.onebusaway.iphone
//
//  Created by Aaron Brethorst on 3/4/16.
//  Copyright © 2016 OneBusAway. All rights reserved.
//

#import "OBAParallaxTableHeaderView.h"
#import <OBAKit/OBAKit.h>
#import <Masonry/Masonry.h>
#import <PromiseKit/PromiseKit.h>
#import <DateTools/DateTools.h>
#import "OBAArrivalsAndDeparturesForStopV2.h"
#import "OBAMapHelpers.h"
#import "OBAImageHelpers.h"
#import "OBAStopIconFactory.h"
#import "OBADateHelpers.h"

#define kHeaderImageViewBackgroundColor [UIColor colorWithWhite:0.f alpha:0.4f]

@interface OBAParallaxTableHeaderView ()
@property(nonatomic,strong,readwrite) UIImageView *headerImageView;
@property(nonatomic,strong,readwrite) UILabel *stopInformationLabel;
@property(nonatomic,strong,readwrite) UIStackView *directionsAndDistanceView;
@property(nonatomic,copy) void (^presenter)(UIViewController *viewController);
@property(nonatomic,strong) OBAStopV2 *stop;
@end

@implementation OBAParallaxTableHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor = [OBATheme backgroundColor];
        self.clipsToBounds = YES;

        _headerImageView = ({
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
            imageView.backgroundColor = kHeaderImageViewBackgroundColor;
            imageView.contentMode = UIViewContentModeCenter;
            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            imageView.alpha = 1.f;
            imageView;
        });
        [self addSubview:_headerImageView];

        _stopInformationLabel = ({
            UILabel *label = [OBAUIBuilder label];
            label.numberOfLines = 0;
            [self.class applyHeaderStylingToLabel:label];
            label;
        });

        _directionsAndDistanceView = ({
            UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            [activity startAnimating];
            UILabel *loading = [[UILabel alloc] initWithFrame:CGRectZero];
            [self.class applyHeaderStylingToLabel:loading];
            loading.text = NSLocalizedString(@"Determining walk time", @"");
            UIStackView *sv = [[UIStackView alloc] initWithArrangedSubviews:@[activity, loading]];
            sv;
        });

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_stopInformationLabel, _directionsAndDistanceView]];
        stack.spacing = [OBATheme defaultPadding];
        stack.axis = UILayoutConstraintAxisVertical;
        [self addSubview:stack];
        [stack mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self).insets(UIEdgeInsetsMake([OBATheme defaultPadding], [OBATheme defaultPadding], [OBATheme defaultPadding], [OBATheme defaultPadding]));
        }];
    }
    return self;
}

#pragma mark - Public

- (void)populateTableHeaderFromArrivalsAndDeparturesModel:(OBAArrivalsAndDeparturesForStopV2*)result {

    self.stop = result.stop;

    if (self.highContrastMode) {
        self.headerImageView.backgroundColor = OBAGREEN;
    }
    else {
        MKMapSnapshotter *snapshotter = ({
            MKMapSnapshotOptions *options = [[MKMapSnapshotOptions alloc] init];

            CGFloat squareDimension = MAX(CGRectGetWidth([UIScreen mainScreen].bounds), CGRectGetHeight([UIScreen mainScreen].bounds));
            CGSize squareSize = CGSizeMake(squareDimension, squareDimension);

            options.region = [OBAMapHelpers coordinateRegionWithCenterCoordinate:self.stop.coordinate zoomLevel:15 viewSize:squareSize];
            options.size = squareSize;
            options.scale = [[UIScreen mainScreen] scale];
            [[MKMapSnapshotter alloc] initWithOptions:options];
        });

        [snapshotter promise].thenInBackground(^(MKMapSnapshot *snapshot) {
            UIImage *annotatedImage = [OBAImageHelpers draw:[OBAStopIconFactory getIconForStop:result.stop]
                                                       onto:snapshot.image
                                                    atPoint:[snapshot pointForCoordinate:self.stop.coordinate]];
            return [OBAImageHelpers colorizeImage:annotatedImage withColor:kHeaderImageViewBackgroundColor];
        }).then(^(UIImage *colorizedImage) {
            self.headerImageView.image = colorizedImage;
        });
    }

    NSMutableArray *stopMetadata = [[NSMutableArray alloc] init];

    if (result.stop.name) {
        [stopMetadata addObject:result.stop.name];
    }

    NSString *stopNumber = nil;

    if (result.stop.direction) {
        stopNumber = [NSString stringWithFormat:@"%@ #%@ - %@ %@", NSLocalizedString(@"Stop", @"text"), result.stop.code, result.stop.direction, NSLocalizedString(@"bound", @"text")];
    }
    else {
        stopNumber = [NSString stringWithFormat:@"%@ #%@", NSLocalizedString(@"Stop", @"text"), result.stop.code];
    }
    [stopMetadata addObject:stopNumber];

    NSString *stopRoutes = [result.stop routeNamesAsString];
    if (stopRoutes) {
        [stopMetadata addObject:[NSString stringWithFormat:NSLocalizedString(@"Routes: %@", @""), stopRoutes]];
    }

    self.stopInformationLabel.text = [stopMetadata componentsJoinedByString:@"\r\n"];

    [self loadETAToLocation:self.stop.coordinate];
}

- (void)loadETAToLocation:(CLLocationCoordinate2D)coordinate {

    static NSUInteger iterations = 0;

    [CLLocationManager until:^BOOL(CLLocation *location) {
        iterations += 1;
        if (iterations >= 5) {
            return YES;
        }
        else {
            return location.horizontalAccuracy <= kCLLocationAccuracyNearestTenMeters;
        }
    }].thenInBackground(^(CLLocation* currentLocation) {
        MKPlacemark *sourcePlacemark = [[MKPlacemark alloc] initWithCoordinate:currentLocation.coordinate addressDictionary:nil];
        MKPlacemark *destinationPlacemark = [[MKPlacemark alloc] initWithCoordinate:coordinate addressDictionary:nil];
        MKDirections *directions = [[MKDirections alloc] initWithRequest:({
            MKDirectionsRequest *r = [[MKDirectionsRequest alloc] init];
            r.source = [[MKMapItem alloc] initWithPlacemark:sourcePlacemark];
            r.destination = [[MKMapItem alloc] initWithPlacemark:destinationPlacemark];
            r.transportType = MKDirectionsTransportTypeWalking;
            r;
        })];
        return [directions calculateETA];
    }).then(^(MKETAResponse* ETA) {
        UILabel *label = [OBAUIBuilder label];
        [OBAParallaxTableHeaderView applyHeaderStylingToLabel:label];

        label.text = [NSString stringWithFormat:@"Walk to stop: %@ — %.0f min, arriving at %@.", [OBAMapHelpers stringFromDistance:ETA.distance],
                      [[NSDate dateWithTimeIntervalSinceNow:ETA.expectedTravelTime] minutesUntil],
                      [OBADateHelpers formatShortTimeNoDate:ETA.expectedArrivalDate]];

        label.userInteractionEnabled = YES;

        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showWalkingDirections:)];
        [label addGestureRecognizer:tapRecognizer];

        [self.directionsAndDistanceView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [self.directionsAndDistanceView addArrangedSubview:label];
    }).catch(^(NSError *error) {
        NSLog(@"Unable to calculate walk time to stop: %@", error);
        [self.directionsAndDistanceView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }).finally(^{
        iterations = 0;
    });
}

#pragma mark - Show Walking Directions

- (void)showWalkingDirections:(UITapGestureRecognizer*)tap {
    MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:self.stop.coordinate addressDictionary:nil];
    MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
    mapItem.name = self.stop.name;

    [mapItem openInMapsWithLaunchOptions:@{
                                           MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
                                           MKLaunchOptionsMapTypeKey: @(MKMapTypeStandard),
                                           MKLaunchOptionsShowsTrafficKey: @NO
                                           }];
}

#pragma mark - Private Helpers

+ (void)applyHeaderStylingToLabel:(UILabel*)label {
    label.textColor = [UIColor whiteColor];
    label.shadowColor = [UIColor colorWithWhite:0.f alpha:0.5f];
    label.shadowOffset = CGSizeMake(0, 1);
    label.font = [OBATheme bodyFont];
}

@end
