#import "PhonePodViewController.h"
#import "ClickWheelView.h"
#import <MediaPlayer/MediaPlayer.h>

@interface PhonePodViewController () <ClickWheelViewDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) MPMusicPlayerController *player;
@property (nonatomic, strong) NSArray *songs;

@property (nonatomic, strong) UIView *chromeView;      // "корпус" плеера
@property (nonatomic, strong) UIView *screenView;       // "экранчик" сверху
@property (nonatomic, strong) UITableView *libraryTableView;
@property (nonatomic, strong) UIView *nowPlayingView;
@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) ClickWheelView *wheel;

@property (nonatomic, assign) NSInteger selectedRow;
@property (nonatomic, assign) BOOL showingNowPlaying;
@property (nonatomic, assign) CGFloat scrollAccumulator;
@property (nonatomic, assign) CGFloat listScrollAccumulator;

@property (nonatomic, strong) NSTimer *progressTimer;

@end

@implementation PhonePodViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor blackColor];

	self.player = [MPMusicPlayerController applicationMusicPlayer];
	self.songs = @[];
	self.selectedRow = 0;
	self.listScrollAccumulator = 0;

	[self buildChrome];
	[self buildScreen];
	[self buildWheel];
	[self loadLibrary];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(nowPlayingItemChanged)
		name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification
		object:self.player];
	[self.player beginGeneratingPlaybackNotifications];
}

#pragma mark - Layout

- (void)buildChrome {
	CGRect b = self.view.bounds;
	CGFloat margin = 24;
	CGFloat width = b.size.width - margin * 2;

	self.chromeView = [[UIView alloc] initWithFrame:CGRectMake(margin, 50, width, b.size.height - 100)];
	self.chromeView.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1.0];
	self.chromeView.layer.cornerRadius = 22;
	self.chromeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:self.chromeView];
}

- (void)buildScreen {
	CGFloat w = self.chromeView.bounds.size.width;
	CGFloat pad = 14;
	CGFloat screenHeight = self.chromeView.bounds.size.height * 0.38;

	self.screenView = [[UIView alloc] initWithFrame:CGRectMake(pad, pad, w - pad * 2, screenHeight)];
	self.screenView.backgroundColor = [UIColor whiteColor];
	self.screenView.layer.cornerRadius = 6;
	self.screenView.layer.borderColor = [UIColor colorWithWhite:0.6 alpha:1.0].CGColor;
	self.screenView.layer.borderWidth = 1.0;
	self.screenView.clipsToBounds = YES;
	self.screenView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.chromeView addSubview:self.screenView];

	// Библиотека
	self.libraryTableView = [[UITableView alloc] initWithFrame:self.screenView.bounds style:UITableViewStylePlain];
	self.libraryTableView.dataSource = self;
	self.libraryTableView.delegate = self;
	self.libraryTableView.rowHeight = 34;
	self.libraryTableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	self.libraryTableView.userInteractionEnabled = NO; // навигация только колесом
	self.libraryTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.screenView addSubview:self.libraryTableView];

	// Now Playing
	self.nowPlayingView = [[UIView alloc] initWithFrame:self.screenView.bounds];
	self.nowPlayingView.backgroundColor = [UIColor whiteColor];
	self.nowPlayingView.hidden = YES;
	self.nowPlayingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.screenView addSubview:self.nowPlayingView];

	CGFloat artSize = screenHeight * 0.55;
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
	CGFloat wheelSize = w - 28;
	CGFloat top = CGRectGetMaxY(self.screenView.frame) + 20;

	self.wheel = [[ClickWheelView alloc] initWithFrame:CGRectMake((w - wheelSize) / 2, top, wheelSize, wheelSize)];
	self.wheel.delegate = self;
	self.wheel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[self.chromeView addSubview:self.wheel];
}

#pragma mark - Библиотека

- (void)loadLibrary {
	MPMediaQuery *query = [MPMediaQuery songsQuery];
	self.songs = query.items ?: @[];
	[self.libraryTableView reloadData];
	if (self.songs.count > 0) {
		[self highlightRow:0];
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.songs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellId = @"song";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	MPMediaItem *item = self.songs[indexPath.row];
	cell.textLabel.text = [item valueForProperty:MPMediaItemPropertyTitle] ?: @"Без названия";
	cell.detailTextLabel.text = [item valueForProperty:MPMediaItemPropertyArtist] ?: @"";
	cell.backgroundColor = (indexPath.row == self.selectedRow) ? [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] : [UIColor whiteColor];
	cell.textLabel.textColor = (indexPath.row == self.selectedRow) ? [UIColor whiteColor] : [UIColor blackColor];
	cell.detailTextLabel.textColor = (indexPath.row == self.selectedRow) ? [UIColor whiteColor] : [UIColor darkGrayColor];
	return cell;
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
	[self showNowPlaying:YES];
	[self updateNowPlayingInfo];
	[self startProgressTimer];
}

#pragma mark - Now Playing

- (void)showNowPlaying:(BOOL)show {
	self.showingNowPlaying = show;
	self.nowPlayingView.hidden = !show;
	self.libraryTableView.hidden = show;
}

- (void)nowPlayingItemChanged {
	[self updateNowPlayingInfo];
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
	self.statusLabel.text = (self.player.playbackState == MPMusicPlaybackStatePlaying) ? @"Воспроизведение" : @"Пауза";
}

#pragma mark - ClickWheelViewDelegate

- (void)clickWheelDidScrollWithAngleDelta:(CGFloat)angleDelta {
	if (self.showingNowPlaying) {
		// колесо в Now Playing = громкость
		self.player.volume += (angleDelta > 0 ? 0.03 : -0.03);
		return;
	}

	// колесо в библиотеке = навигация по списку
	self.listScrollAccumulator += angleDelta;
	CGFloat stepThreshold = 0.35; // радиан на строку
	while (self.listScrollAccumulator > stepThreshold) {
		[self highlightRow:self.selectedRow + 1];
		self.listScrollAccumulator -= stepThreshold;
	}
	while (self.listScrollAccumulator < -stepThreshold) {
		[self highlightRow:self.selectedRow - 1];
		self.listScrollAccumulator += stepThreshold;
	}
}

- (void)clickWheelDidPressButton:(ClickWheelButton)button {
	switch (button) {
		case ClickWheelButtonMenu:
			[self showNowPlaying:NO];
			break;
		case ClickWheelButtonCenter:
			if (!self.showingNowPlaying) {
				[self playSelectedSong];
			}
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

@end
