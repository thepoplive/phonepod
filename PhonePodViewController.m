#import "PhonePodViewController.h"
#import "ClickWheelView.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AssetsLibrary/AssetsLibrary.h>

typedef NS_ENUM(NSInteger, PPScreen) {
	PPScreenMainMenu,
	PPScreenMusic,
	PPScreenPlaylists,
	PPScreenPhotos,
	PPScreenVideos,
	PPScreenExtras,
	PPScreenSettings,
	PPScreenLanguage,
	PPScreenNowPlaying,
	PPScreenPhotoViewer
};

@interface PhonePodViewController () <ClickWheelViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) MPMusicPlayerController *player;
@property (nonatomic, strong) NSArray *songs;

@property (nonatomic, strong) UIView *chromeView;
@property (nonatomic, strong) UIView *screenView;
@property (nonatomic, strong) UILabel *topBarLabel;

@property (nonatomic, strong) UITableView *mainMenuTableView;
@property (nonatomic, assign) NSInteger mainMenuSelectedRow;
@property (nonatomic, assign) CGFloat mainMenuScrollAccumulator;

@property (nonatomic, strong) UITableView *libraryTableView;
@property (nonatomic, assign) NSInteger selectedRow;
@property (nonatomic, assign) CGFloat listScrollAccumulator;

@property (nonatomic, strong) UITableView *settingsTableView;
@property (nonatomic, assign) NSInteger settingsSelectedRow;
@property (nonatomic, assign) CGFloat settingsScrollAccumulator;
@property (nonatomic, strong) UILabel *settingsFooterLabel;
@property (nonatomic, copy) NSString *language;

@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, strong) NSMutableArray *assets;
@property (nonatomic, strong) UIScrollView *photosGridView;
@property (nonatomic, strong) NSMutableArray *photoThumbViews;
@property (nonatomic, assign) NSInteger photoIndex;
@property (nonatomic, assign) NSInteger photosPerRow;
@property (nonatomic, assign) CGFloat photoCellSize;
@property (nonatomic, assign) CGFloat photoScrollAccumulator;
@property (nonatomic, assign) BOOL photosLoadFailed;
@property (nonatomic, strong) UILabel *photosEmptyLabel;
@property (nonatomic, strong) UIView *photoViewerView;
@property (nonatomic, strong) UIImageView *photoViewerImageView;

@property (nonatomic, strong) UIView *placeholderView;
@property (nonatomic, strong) UILabel *placeholderLabel;

@property (nonatomic, strong) UIView *nowPlayingView;
@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) ClickWheelView *wheel;
@property (nonatomic, strong) NSMutableArray *screenStack;
@property (nonatomic, strong) NSTimer *progressTimer;

@end

@implementation PhonePodViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor blackColor];

	self.player = [MPMusicPlayerController systemMusicPlayer];
	self.songs = @[];
	self.selectedRow = 0;
	self.mainMenuSelectedRow = 0;
	self.settingsSelectedRow = 0;
	self.listScrollAccumulator = 0;
	self.mainMenuScrollAccumulator = 0;
	self.settingsScrollAccumulator = 0;
	self.photoIndex = 0;
	self.photosPerRow = 4;
	self.assets = [NSMutableArray array];
	self.photoThumbViews = [NSMutableArray array];
	NSString *savedLang = [[NSUserDefaults standardUserDefaults] objectForKey:@"PhonePodLanguage"];
	_language = (savedLang != nil) ? savedLang : @"en";
	self.screenStack = [NSMutableArray arrayWithObject:@(PPScreenMainMenu)];

	[self buildChrome];
	[self buildScreen];
	[self buildWheel];
	[self loadLibrary];
	[self loadPhotos];
	[self displayCurrentScreen];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(nowPlayingItemChanged)
		name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification
		object:self.player];
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(playbackStateChanged)
		name:MPMusicPlayerControllerPlaybackStateDidChangeNotification
		object:self.player];
	[self.player beginGeneratingPlaybackNotifications];

	[self playbackStateChanged];
}

- (void)buildChrome {
	self.chromeView = [[UIView alloc] initWithFrame:self.view.bounds];
	self.chromeView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
	self.chromeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:self.chromeView];
}

- (void)buildScreen {
	CGFloat topInset = 28;
	CGFloat pad = 14;
	CGFloat w = self.chromeView.bounds.size.width - pad * 2;
	CGFloat screenHeight = self.chromeView.bounds.size.height * 0.40;

	self.screenView = [[UIView alloc] initWithFrame:CGRectMake(pad, topInset, w, screenHeight)];
	self.screenView.backgroundColor = [UIColor whiteColor];
	self.screenView.layer.cornerRadius = 4;
	self.screenView.layer.borderColor = [UIColor colorWithWhite:0.55 alpha:1.0].CGColor;
	self.screenView.layer.borderWidth = 1.0;
	self.screenView.clipsToBounds = YES;
	self.screenView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.chromeView addSubview:self.screenView];

	CGFloat topBarHeight = 20;
	self.topBarLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, topBarHeight)];
	self.topBarLabel.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
	self.topBarLabel.textColor = [UIColor whiteColor];
	self.topBarLabel.font = [UIFont boldSystemFontOfSize:12];
	self.topBarLabel.textAlignment = NSTextAlignmentCenter;
	self.topBarLabel.text = @"iPod";
	self.topBarLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.screenView addSubview:self.topBarLabel];

	CGRect contentFrame = CGRectMake(0, topBarHeight, w, screenHeight - topBarHeight);

	self.mainMenuTableView = [[UITableView alloc] initWithFrame:contentFrame style:UITableViewStylePlain];
	self.mainMenuTableView.dataSource = self;
	self.mainMenuTableView.delegate = self;
	self.mainMenuTableView.rowHeight = 32;
	self.mainMenuTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	self.mainMenuTableView.userInteractionEnabled = NO;
	self.mainMenuTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.screenView addSubview:self.mainMenuTableView];

	self.libraryTableView = [[UITableView alloc] initWithFrame:contentFrame style:UITableViewStylePlain];
	self.libraryTableView.dataSource = self;
	self.libraryTableView.delegate = self;
	self.libraryTableView.rowHeight = 34;
	self.libraryTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	self.libraryTableView.userInteractionEnabled = NO;
	self.libraryTableView.hidden = YES;
	self.libraryTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.screenView addSubview:self.libraryTableView];

	self.settingsTableView = [[UITableView alloc] initWithFrame:contentFrame style:UITableViewStylePlain];
	self.settingsTableView.dataSource = self;
	self.settingsTableView.delegate = self;
	self.settingsTableView.rowHeight = 32;
	self.settingsTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	self.settingsTableView.userInteractionEnabled = NO;
	self.settingsTableView.hidden = YES;
	self.settingsTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.screenView addSubview:self.settingsTableView];

	self.settingsFooterLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, contentFrame.size.height - 26, w - 16, 20)];
	self.settingsFooterLabel.font = [UIFont systemFontOfSize:10];
	self.settingsFooterLabel.textColor = [UIColor grayColor];
	self.settingsFooterLabel.textAlignment = NSTextAlignmentCenter;
	self.settingsFooterLabel.text = @"сделано blxckfvde с любовью <3";
	self.settingsFooterLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[self.screenView addSubview:self.settingsFooterLabel];

	self.photosGridView = [[UIScrollView alloc] initWithFrame:contentFrame];
	self.photosGridView.backgroundColor = [UIColor whiteColor];
	self.photosGridView.userInteractionEnabled = NO;
	self.photosGridView.hidden = YES;
	self.photosGridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.screenView addSubview:self.photosGridView];

	self.photosEmptyLabel = [[UILabel alloc] initWithFrame:self.photosGridView.bounds];
	self.photosEmptyLabel.numberOfLines = 0;
	self.photosEmptyLabel.textAlignment = NSTextAlignmentCenter;
	self.photosEmptyLabel.textColor = [UIColor grayColor];
	self.photosEmptyLabel.font = [UIFont systemFontOfSize:13];
	self.photosEmptyLabel.hidden = YES;
	self.photosEmptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.photosGridView addSubview:self.photosEmptyLabel];

	self.photoViewerView = [[UIView alloc] initWithFrame:contentFrame];
	self.photoViewerView.backgroundColor = [UIColor blackColor];
	self.photoViewerView.hidden = YES;
	self.photoViewerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.screenView addSubview:self.photoViewerView];

	self.photoViewerImageView = [[UIImageView alloc] initWithFrame:self.photoViewerView.bounds];
	self.photoViewerImageView.contentMode = UIViewContentModeScaleAspectFit;
	self.photoViewerImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.photoViewerView addSubview:self.photoViewerImageView];

	self.placeholderView = [[UIView alloc] initWithFrame:contentFrame];
	self.placeholderView.backgroundColor = [UIColor whiteColor];
	self.placeholderView.hidden = YES;
	self.placeholderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.screenView addSubview:self.placeholderView];

	self.placeholderLabel = [[UILabel alloc] initWithFrame:self.placeholderView.bounds];
	self.placeholderLabel.numberOfLines = 0;
	self.placeholderLabel.textAlignment = NSTextAlignmentCenter;
	self.placeholderLabel.textColor = [UIColor grayColor];
	self.placeholderLabel.font = [UIFont systemFontOfSize:13];
	self.placeholderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.placeholderView addSubview:self.placeholderLabel];

	self.nowPlayingView = [[UIView alloc] initWithFrame:contentFrame];
	self.nowPlayingView.backgroundColor = [UIColor whiteColor];
	self.nowPlayingView.hidden = YES;
	self.nowPlayingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.screenView addSubview:self.nowPlayingView];

	CGFloat contentHeight = contentFrame.size.height;
	CGFloat artSize = contentHeight * 0.6;

	self.artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(8, 8, artSize, artSize)];
	self.artworkView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
	self.artworkView.contentMode = UIViewContentModeScaleAspectFill;
	self.artworkView.clipsToBounds = YES;
	[self.nowPlayingView addSubview:self.artworkView];

	CGFloat textX = artSize + 16;
	CGFloat textW = self.nowPlayingView.bounds.size.width - textX - 8;

	self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 8, textW, 20)];
	self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
	self.titleLabel.text = [self lstr:@"No track" ru:@"Нет трека"];
	[self.nowPlayingView addSubview:self.titleLabel];

	self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 30, textW, 18)];
	self.artistLabel.font = [UIFont systemFontOfSize:12];
	self.artistLabel.textColor = [UIColor darkGrayColor];
	[self.nowPlayingView addSubview:self.artistLabel];

	self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 52, textW, 16)];
	self.statusLabel.font = [UIFont systemFontOfSize:11];
	self.statusLabel.textColor = [UIColor grayColor];
	self.statusLabel.text = [self lstr:@"Stopped" ru:@"Остановлено"];
	[self.nowPlayingView addSubview:self.statusLabel];

	self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
	self.progressView.frame = CGRectMake(8, artSize + 16, self.nowPlayingView.bounds.size.width - 16, 4);
	self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.nowPlayingView addSubview:self.progressView];
}

- (void)buildWheel {
	CGFloat w = self.chromeView.bounds.size.width;
	CGFloat wheelTop = CGRectGetMaxY(self.screenView.frame) + 24;
	CGFloat maxWheelWidth = w - 40;
	CGFloat maxWheelHeight = self.chromeView.bounds.size.height - wheelTop - 30;
	CGFloat wheelSize = MIN(maxWheelWidth, maxWheelHeight);

	self.wheel = [[ClickWheelView alloc] initWithFrame:CGRectMake((w - wheelSize) / 2, wheelTop, wheelSize, wheelSize)];
	self.wheel.delegate = self;
	self.wheel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[self.chromeView addSubview:self.wheel];
}

- (PPScreen)currentScreen {
	return [[self.screenStack lastObject] integerValue];
}

- (void)pushScreen:(PPScreen)screen {
	[self.screenStack addObject:@(screen)];
	[self displayCurrentScreen];
}

- (void)popScreen {
	if (self.screenStack.count > 1) {
		[self.screenStack removeLastObject];
		[self displayCurrentScreen];
	}
}

- (void)displayCurrentScreen {
	PPScreen screen = self.currentScreen;

	self.mainMenuTableView.hidden = (screen != PPScreenMainMenu);
	self.libraryTableView.hidden = (screen != PPScreenMusic);
	self.settingsTableView.hidden = !(screen == PPScreenSettings || screen == PPScreenLanguage);
	self.settingsFooterLabel.hidden = (screen != PPScreenSettings);
	self.photosGridView.hidden = (screen != PPScreenPhotos);
	self.photoViewerView.hidden = (screen != PPScreenPhotoViewer);
	self.nowPlayingView.hidden = (screen != PPScreenNowPlaying);
	self.placeholderView.hidden = !(screen == PPScreenPlaylists || screen == PPScreenVideos || screen == PPScreenExtras);

	switch (screen) {
		case PPScreenMainMenu: self.topBarLabel.text = @"iPod"; break;
		case PPScreenMusic: self.topBarLabel.text = [self lstr:@"Music" ru:@"Музыка"]; break;
		case PPScreenPlaylists:
			self.topBarLabel.text = [self lstr:@"Playlists" ru:@"Плейлисты"];
			self.placeholderLabel.text = [self lstr:@"Playlists\n(in development)" ru:@"Плейлисты\n(в разработке)"];
			break;
		case PPScreenPhotos:
			self.topBarLabel.text = [self lstr:@"Photos" ru:@"Фото"];
			[self ensurePhotoGrid];
			break;
		case PPScreenVideos:
			self.topBarLabel.text = [self lstr:@"Videos" ru:@"Видео"];
			self.placeholderLabel.text = [self lstr:@"Videos\n(in development)" ru:@"Видео\n(в разработке)"];
			break;
		case PPScreenExtras:
			self.topBarLabel.text = [self lstr:@"Extras" ru:@"Дополнения"];
			self.placeholderLabel.text = [self lstr:@"Extras\n(in development)" ru:@"Дополнения\n(в разработке)"];
			break;
		case PPScreenSettings:
			self.topBarLabel.text = [self lstr:@"Settings" ru:@"Настройки"];
			[self highlightSettingsRow:0];
			break;
		case PPScreenLanguage:
			self.topBarLabel.text = [self lstr:@"Language" ru:@"Язык"];
			[self highlightSettingsRow:0];
			break;
		case PPScreenNowPlaying: self.topBarLabel.text = [self lstr:@"Now Playing" ru:@"Сейчас играет"]; break;
		case PPScreenPhotoViewer:
			self.topBarLabel.text = [self lstr:@"Photos" ru:@"Фото"];
			[self showCurrentPhoto];
			break;
	}
}

- (NSString *)lstr:(NSString *)en ru:(NSString *)ru {
	return [self.language isEqualToString:@"ru"] ? ru : en;
}

- (NSArray *)mainMenuItems {
	return @[
		[self lstr:@"Music" ru:@"Музыка"],
		[self lstr:@"Photos" ru:@"Фото"],
		[self lstr:@"Videos" ru:@"Видео"],
		[self lstr:@"Playlists" ru:@"Плейлисты"],
		[self lstr:@"Extras" ru:@"Дополнения"],
		[self lstr:@"Settings" ru:@"Настройки"],
		[self lstr:@"Shuffle Songs" ru:@"Перемешать"],
		[self lstr:@"Now Playing" ru:@"Сейчас играет"]
	];
}

- (void)setLanguage:(NSString *)language {
	_language = language;
	[[NSUserDefaults standardUserDefaults] setObject:language forKey:@"PhonePodLanguage"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self.mainMenuTableView reloadData];
	[self.libraryTableView reloadData];
	[self.settingsTableView reloadData];
	[self displayCurrentScreen];
}

- (NSInteger)mainMenuNumberOfRows {
	return self.mainMenuItems.count;
}

- (void)highlightMainMenuRow:(NSInteger)row {
	row = MAX(0, MIN(row, (NSInteger)self.mainMenuItems.count - 1));
	self.mainMenuSelectedRow = row;
	[self.mainMenuTableView reloadData];
	[self.mainMenuTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]
		atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)selectMainMenuItem:(NSInteger)row {
	switch (row) {
		case 0: [self pushScreen:PPScreenMusic]; break;
		case 1: [self pushScreen:PPScreenPhotos]; break;
		case 2: [self pushScreen:PPScreenVideos]; break;
		case 3: [self pushScreen:PPScreenPlaylists]; break;
		case 4: [self pushScreen:PPScreenExtras]; break;
		case 5: [self pushScreen:PPScreenSettings]; break;
		case 6: [self shuffleAndPlay]; break;
		case 7: [self pushScreen:PPScreenNowPlaying]; break;
		default: break;
	}
}

- (void)loadLibrary {
	MPMediaQuery *query = [MPMediaQuery songsQuery];
	self.songs = query.items ?: @[];
	[self.libraryTableView reloadData];
	if (self.songs.count > 0) {
		[self highlightRow:0];
	}
}

- (void)highlightSettingsRow:(NSInteger)row {
	NSInteger count = (self.currentScreen == PPScreenLanguage) ? 2 : 1;
	if (count == 0) return;
	row = MAX(0, MIN(row, count - 1));
	self.settingsSelectedRow = row;
	[self.settingsTableView reloadData];
	[self.settingsTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]
		atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)selectSettingsItem {
	if (self.currentScreen == PPScreenLanguage) {
		[self setLanguage:(self.settingsSelectedRow == 0) ? @"en" : @"ru"];
		[self popScreen];
	} else {
		[self pushScreen:PPScreenLanguage];
	}
}

- (void)loadPhotos {
	self.assetsLibrary = [[ALAssetsLibrary alloc] init];
	__weak PhonePodViewController *weakSelf = self;
	[self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
		usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
			if (group) {
				[group setAssetsFilter:[ALAssetsFilter allPhotos]];
				[group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
					if (result) [weakSelf.assets addObject:result];
				}];
			} else {
				dispatch_async(dispatch_get_main_queue(), ^{
					[weakSelf ensurePhotoGrid];
				});
			}
		} failureBlock:^(NSError *error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				weakSelf.photosLoadFailed = YES;
				[weakSelf ensurePhotoGrid];
			});
		}];
}

- (void)ensurePhotoGrid {
	if (!self.photosGridView) return;
	if (self.assets.count == 0) {
		self.photosEmptyLabel.hidden = NO;
		self.photosEmptyLabel.text = self.photosLoadFailed
			? [self lstr:@"No access to photos" ru:@"Нет доступа к фото"]
			: [self lstr:@"No photos" ru:@"Нет фотографий"];
		for (UIView *v in self.photoThumbViews) [v removeFromSuperview];
		[self.photoThumbViews removeAllObjects];
		return;
	}
	self.photosEmptyLabel.hidden = YES;
	if (self.photoThumbViews.count != self.assets.count) {
		[self rebuildPhotoGrid];
	} else {
		[self highlightPhoto:self.photoIndex];
	}
}

- (void)rebuildPhotoGrid {
	for (UIView *v in self.photoThumbViews) [v removeFromSuperview];
	[self.photoThumbViews removeAllObjects];

	CGFloat pad = 3;
	CGFloat totalW = self.photosGridView.bounds.size.width - pad * 2;
	if (totalW <= 0 || self.assets.count == 0) return;

	self.photoCellSize = floor((totalW - (self.photosPerRow - 1) * pad) / self.photosPerRow);
	NSInteger rows = (self.assets.count + self.photosPerRow - 1) / self.photosPerRow;
	self.photosGridView.contentSize = CGSizeMake(self.photosGridView.bounds.size.width, rows * (self.photoCellSize + pad) + pad);

	for (NSInteger i = 0; i < self.assets.count; i++) {
		NSInteger r = i / self.photosPerRow;
		NSInteger c = i % self.photosPerRow;
		CGRect f = CGRectMake(pad + c * (self.photoCellSize + pad), pad + r * (self.photoCellSize + pad),
			self.photoCellSize, self.photoCellSize);
		UIImageView *v = [[UIImageView alloc] initWithFrame:f];
		v.backgroundColor = [UIColor lightGrayColor];
		v.contentMode = UIViewContentModeScaleAspectFill;
		v.clipsToBounds = YES;
		ALAsset *asset = self.assets[i];
		v.image = [UIImage imageWithCGImage:asset.aspectRatioThumbnail];
		[self.photosGridView addSubview:v];
		[self.photoThumbViews addObject:v];
	}
	[self highlightPhoto:self.photoIndex];
}

- (void)highlightPhoto:(NSInteger)index {
	if (self.assets.count == 0) return;
	index = MAX(0, MIN(index, (NSInteger)self.assets.count - 1));
	self.photoIndex = index;
	UIColor *sel = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
	for (NSInteger i = 0; i < self.photoThumbViews.count; i++) {
		UIImageView *v = self.photoThumbViews[i];
		v.layer.borderWidth = (i == index) ? 2.0 : 0.0;
		v.layer.borderColor = sel.CGColor;
	}
	NSInteger row = index / self.photosPerRow;
	CGFloat y = row * (self.photoCellSize + 3);
	CGRect vis = self.photosGridView.bounds;
	if (y < vis.origin.y) {
		[self.photosGridView setContentOffset:CGPointMake(0, y) animated:YES];
	} else if (y + self.photoCellSize > vis.origin.y + vis.size.height) {
		[self.photosGridView setContentOffset:CGPointMake(0, y + self.photoCellSize - vis.size.height) animated:YES];
	}
}

- (void)showCurrentPhoto {
	if (self.assets.count == 0) {
		self.photoViewerImageView.image = nil;
		return;
	}
	ALAsset *asset = self.assets[self.photoIndex];
	CGImageRef image = [[asset defaultRepresentation] fullScreenImage];
	if (!image) image = asset.aspectRatioThumbnail;
	self.photoViewerImageView.image = [UIImage imageWithCGImage:image];
}

- (void)highlightRow:(NSInteger)row {
	if (self.songs.count == 0) return;
	row = MAX(0, MIN(row, (NSInteger)self.songs.count - 1));
	self.selectedRow = row;
	[self.libraryTableView reloadData];
	[self.libraryTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]
		atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)playSelectedSong {
	if (self.songs.count == 0) return;
	MPMediaItem *item = self.songs[self.selectedRow];
	MPMediaItemCollection *collection = [MPMediaItemCollection collectionWithItems:@[item]];
	[self.player setQueueWithItemCollection:collection];
	[self.player play];
	[self pushScreen:PPScreenNowPlaying];
	[self updateNowPlayingInfo];
	[self startProgressTimer];
}

- (void)shuffleAndPlay {
	if (self.songs.count == 0) return;
	NSMutableArray *shuffled = [self.songs mutableCopy];
	for (NSInteger i = shuffled.count - 1; i > 0; i--) {
		NSInteger j = arc4random_uniform((u_int32_t)(i + 1));
		[shuffled exchangeObjectAtIndex:i withObjectAtIndex:j];
	}
	MPMediaItemCollection *collection = [MPMediaItemCollection collectionWithItems:shuffled];
	[self.player setQueueWithItemCollection:collection];
	[self.player play];
	[self pushScreen:PPScreenNowPlaying];
	[self updateNowPlayingInfo];
	[self startProgressTimer];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (tableView == self.mainMenuTableView) return [self mainMenuNumberOfRows];
	if (tableView == self.settingsTableView) return (self.currentScreen == PPScreenLanguage) ? 2 : 1;
	return self.songs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (tableView == self.mainMenuTableView) {
		static NSString *menuCellId = @"menuItem";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:menuCellId];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:menuCellId];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		NSString *title = self.mainMenuItems[indexPath.row];
		cell.textLabel.text = title;
		BOOL selected = (indexPath.row == self.mainMenuSelectedRow);
		cell.backgroundColor = selected ? [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] : [UIColor whiteColor];
		cell.textLabel.textColor = selected ? [UIColor whiteColor] : [UIColor blackColor];
		BOOL isAction = (indexPath.row == 6) || (indexPath.row == 7);
		cell.accessoryType = isAction ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	if (tableView == self.settingsTableView) {
		static NSString *settingsCellId = @"settings";
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:settingsCellId];
		if (!cell) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:settingsCellId];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
		}
		BOOL selected = (indexPath.row == self.settingsSelectedRow);
		cell.backgroundColor = selected ? [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] : [UIColor whiteColor];
		if (self.currentScreen == PPScreenLanguage) {
			BOOL isEnglish = (indexPath.row == 0);
			cell.textLabel.text = isEnglish ? @"English" : @"Русский";
			BOOL isCurrent = [self.language isEqualToString:isEnglish ? @"en" : @"ru"];
			cell.accessoryType = isCurrent ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
			cell.textLabel.textColor = selected ? [UIColor whiteColor]
				: (isCurrent ? [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] : [UIColor blackColor]);
		} else {
			cell.textLabel.text = [self lstr:@"Language" ru:@"Язык"];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.textLabel.textColor = selected ? [UIColor whiteColor] : [UIColor blackColor];
		}
		return cell;
	}

	static NSString *songCellId = @"song";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:songCellId];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:songCellId];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	MPMediaItem *item = self.songs[indexPath.row];
	cell.textLabel.text = [item valueForProperty:MPMediaItemPropertyTitle] ?: [self lstr:@"Unknown" ru:@"Без названия"];
	cell.detailTextLabel.text = [item valueForProperty:MPMediaItemPropertyArtist] ?: @"";
	BOOL selected = (indexPath.row == self.selectedRow);
	cell.backgroundColor = selected ? [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] : [UIColor whiteColor];
	cell.textLabel.textColor = selected ? [UIColor whiteColor] : [UIColor blackColor];
	cell.detailTextLabel.textColor = selected ? [UIColor whiteColor] : [UIColor darkGrayColor];
	return cell;
}

- (void)nowPlayingItemChanged {
	[self updateNowPlayingInfo];
}

- (void)playbackStateChanged {
	BOOL playing = (self.player.playbackState == MPMusicPlaybackStatePlaying);
	self.wheel.isPlaying = playing;
	self.statusLabel.text = playing ? [self lstr:@"Playing" ru:@"Воспроизведение"] : [self lstr:@"Paused" ru:@"Пауза"];
	if (playing) {
		[self startProgressTimer];
	}
}

- (void)updateNowPlayingInfo {
	MPMediaItem *item = self.player.nowPlayingItem;
	if (!item) {
		self.titleLabel.text = [self lstr:@"No track" ru:@"Нет трека"];
		self.artistLabel.text = @"";
		return;
	}
	self.titleLabel.text = [item valueForProperty:MPMediaItemPropertyTitle];
	self.artistLabel.text = [item valueForProperty:MPMediaItemPropertyArtist];

	MPMediaItemArtwork *artwork = [item valueForProperty:MPMediaItemPropertyArtwork];
	if (artwork) {
		self.artworkView.image = [artwork imageWithSize:self.artworkView.bounds.size];
	} else {
		self.artworkView.image = nil;
	}
}

- (void)startProgressTimer {
	[self.progressTimer invalidate];
	self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tickProgress) userInfo:nil repeats:YES];
}

- (void)tickProgress {
	MPMediaItem *item = self.player.nowPlayingItem;
	if (!item) return;
	NSTimeInterval duration = [[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
	NSTimeInterval current = self.player.currentPlaybackTime;
	if (duration > 0) {
		self.progressView.progress = current / duration;
	}
}

- (void)clickWheelDidScrollWithAngleDelta:(CGFloat)angleDelta {
	PPScreen screen = self.currentScreen;
	CGFloat step = 0.35;

	if (screen == PPScreenNowPlaying) {
		self.player.volume += (angleDelta > 0 ? 0.03 : -0.03);
		return;
	}

	if (screen == PPScreenMainMenu) {
		self.mainMenuScrollAccumulator += angleDelta;
		while (self.mainMenuScrollAccumulator > step) {
			[self highlightMainMenuRow:self.mainMenuSelectedRow + 1];
			self.mainMenuScrollAccumulator -= step;
		}
		while (self.mainMenuScrollAccumulator < -step) {
			[self highlightMainMenuRow:self.mainMenuSelectedRow - 1];
			self.mainMenuScrollAccumulator += step;
		}
		return;
	}

	if (screen == PPScreenMusic) {
		self.listScrollAccumulator += angleDelta;
		while (self.listScrollAccumulator > step) {
			[self highlightRow:self.selectedRow + 1];
			self.listScrollAccumulator -= step;
		}
		while (self.listScrollAccumulator < -step) {
			[self highlightRow:self.selectedRow - 1];
			self.listScrollAccumulator += step;
		}
		return;
	}

	if (screen == PPScreenSettings || screen == PPScreenLanguage) {
		self.settingsScrollAccumulator += angleDelta;
		while (self.settingsScrollAccumulator > step) {
			[self highlightSettingsRow:self.settingsSelectedRow + 1];
			self.settingsScrollAccumulator -= step;
		}
		while (self.settingsScrollAccumulator < -step) {
			[self highlightSettingsRow:self.settingsSelectedRow - 1];
			self.settingsScrollAccumulator += step;
		}
		return;
	}

	if (screen == PPScreenPhotos || screen == PPScreenPhotoViewer) {
		self.photoScrollAccumulator += angleDelta;
		CGFloat photoStep = (screen == PPScreenPhotoViewer) ? 0.25 : 0.35;
		while (self.photoScrollAccumulator > photoStep) {
			[self highlightPhoto:self.photoIndex + 1];
			if (screen == PPScreenPhotoViewer) [self showCurrentPhoto];
			self.photoScrollAccumulator -= photoStep;
		}
		while (self.photoScrollAccumulator < -photoStep) {
			[self highlightPhoto:self.photoIndex - 1];
			if (screen == PPScreenPhotoViewer) [self showCurrentPhoto];
			self.photoScrollAccumulator += photoStep;
		}
		return;
	}
}

- (void)clickWheelDidPressButton:(ClickWheelButton)button {
	switch (button) {
		case ClickWheelButtonMenu:
			[self popScreen];
			break;
		case ClickWheelButtonCenter:
			[self handleCenterPress];
			break;
		case ClickWheelButtonPlayPause:
			if (self.player.playbackState == MPMusicPlaybackStatePlaying) {
				[self.player pause];
			} else {
				[self.player play];
			}
			break;
		case ClickWheelButtonNext:
			[self.player skipToNextItem];
			break;
		case ClickWheelButtonPrev:
			[self.player skipToPreviousItem];
			break;
	}
}

- (void)handleCenterPress {
	switch (self.currentScreen) {
		case PPScreenMainMenu:
			[self selectMainMenuItem:self.mainMenuSelectedRow];
			break;
		case PPScreenMusic:
			[self playSelectedSong];
			break;
		case PPScreenPhotos:
			if (self.assets.count > 0) [self pushScreen:PPScreenPhotoViewer];
			break;
		case PPScreenSettings:
		case PPScreenLanguage:
			[self selectSettingsItem];
			break;
		default:
			break;
	}
}

@end
