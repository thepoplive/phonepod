#import "PhonePodViewController.h"
#import "ClickWheelView.h"
#import <MediaPlayer/MediaPlayer.h>

typedef NS_ENUM(NSInteger, PPScreen) {
	PPScreenMainMenu,
	PPScreenMusic,
	PPScreenPlaylists,
	PPScreenPhotos,
	PPScreenVideos,
	PPScreenExtras,
	PPScreenSettings,
	PPScreenNowPlaying
};

@interface PhonePodViewController () <ClickWheelViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) MPMusicPlayerController *player;
@property (nonatomic, strong) NSArray *songs;

@property (nonatomic, strong) UIView *chromeView;
@property (nonatomic, strong) UIView *screenView;
@property (nonatomic, strong) UILabel *topBarLabel;

@property (nonatomic, strong) NSArray *mainMenuItems;
@property (nonatomic, strong) UITableView *mainMenuTableView;
@property (nonatomic, assign) NSInteger mainMenuSelectedRow;
@property (nonatomic, assign) CGFloat mainMenuScrollAccumulator;

@property (nonatomic, strong) UITableView *libraryTableView;
@property (nonatomic, assign) NSInteger selectedRow;
@property (nonatomic, assign) CGFloat listScrollAccumulator;

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
	self.listScrollAccumulator = 0;
	self.mainMenuScrollAccumulator = 0;
	self.screenStack = [NSMutableArray arrayWithObject:@(PPScreenMainMenu)];

	[self buildChrome];
	[self buildScreen];
	[self buildWheel];
	[self loadLibrary];
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

	self.mainMenuItems = @[@"Music", @"Photos", @"Videos", @"Playlists", @"Extras", @"Settings", @"Shuffle Songs", @"Now Playing"];
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
	self.titleLabel.text = @"Нет трека";
	[self.nowPlayingView addSubview:self.titleLabel];

	self.artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 30, textW, 18)];
	self.artistLabel.font = [UIFont systemFontOfSize:12];
	self.artistLabel.textColor = [UIColor darkGrayColor];
	[self.nowPlayingView addSubview:self.artistLabel];

	self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(textX, 52, textW, 16)];
	self.statusLabel.font = [UIFont systemFontOfSize:11];
	self.statusLabel.textColor = [UIColor grayColor];
	self.statusLabel.text = @"Остановлено";
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
	self.nowPlayingView.hidden = (screen != PPScreenNowPlaying);
	self.placeholderView.hidden = !(screen == PPScreenPlaylists || screen == PPScreenPhotos ||
		screen == PPScreenVideos || screen == PPScreenExtras || screen == PPScreenSettings);

	switch (screen) {
		case PPScreenMainMenu: self.topBarLabel.text = @"iPod"; break;
		case PPScreenMusic: self.topBarLabel.text = @"Music"; break;
		case PPScreenPlaylists: self.topBarLabel.text = @"Playlists"; self.placeholderLabel.text = @"Плейлисты\n(в разработке)"; break;
		case PPScreenPhotos: self.topBarLabel.text = @"Photos"; self.placeholderLabel.text = @"Фото\n(в разработке)"; break;
		case PPScreenVideos: self.topBarLabel.text = @"Videos"; self.placeholderLabel.text = @"Видео\n(в разработке)"; break;
		case PPScreenExtras: self.topBarLabel.text = @"Extras"; self.placeholderLabel.text = @"Дополнения\n(в разработке)"; break;
		case PPScreenSettings: self.topBarLabel.text = @"Settings"; self.placeholderLabel.text = @"Настройки\n(в разработке)"; break;
		case PPScreenNowPlaying: self.topBarLabel.text = @"Now Playing"; break;
	}
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
	NSString *item = self.mainMenuItems[row];
	if ([item isEqualToString:@"Music"]) {
		[self pushScreen:PPScreenMusic];
	} else if ([item isEqualToString:@"Photos"]) {
		[self pushScreen:PPScreenPhotos];
	} else if ([item isEqualToString:@"Videos"]) {
		[self pushScreen:PPScreenVideos];
	} else if ([item isEqualToString:@"Playlists"]) {
		[self pushScreen:PPScreenPlaylists];
	} else if ([item isEqualToString:@"Extras"]) {
		[self pushScreen:PPScreenExtras];
	} else if ([item isEqualToString:@"Settings"]) {
		[self pushScreen:PPScreenSettings];
	} else if ([item isEqualToString:@"Shuffle Songs"]) {
		[self shuffleAndPlay];
	} else if ([item isEqualToString:@"Now Playing"]) {
		[self pushScreen:PPScreenNowPlaying];
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
		BOOL isAction = [title isEqualToString:@"Shuffle Songs"] || [title isEqualToString:@"Now Playing"];
		cell.accessoryType = isAction ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	static NSString *songCellId = @"song";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:songCellId];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:songCellId];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	MPMediaItem *item = self.songs[indexPath.row];
	cell.textLabel.text = [item valueForProperty:MPMediaItemPropertyTitle] ?: @"Без названия";
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
	self.statusLabel.text = playing ? @"Воспроизведение" : @"Пауза";
	if (playing) {
		[self startProgressTimer];
	}
}

- (void)updateNowPlayingInfo {
	MPMediaItem *item = self.player.nowPlayingItem;
	if (!item) {
		self.titleLabel.text = @"Нет трека";
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
		default:
			break;
	}
}

@end
