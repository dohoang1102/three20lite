//
// Copyright 2009-2011 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "TTTableViewController.h"

// UI
#import "TTActivityLabel.h"
#import "TTErrorView.h"
#import "TTListDataSource.h"
#import "TTTableView.h"
#import "TTTableViewDelegate.h"
#import "TTTableViewVarHeightDelegate.h"
#import "UIViewAdditions.h"
#import "UITableViewAdditions.h"

// UICommon
#import "TTGlobalUICommon.h"
#import "UIViewControllerAdditions.h"

// Style
#import "TTGlobalStyle.h"
#import "TTDefaultStyleSheet.h"

// Core
#import "TTCorePreprocessorMacros.h"
#import "TTGlobalCoreLocale.h"
#import "TTGlobalCoreRects.h"
#import "TTDebug.h"
#import "TTDebugFlags.h"


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation TTTableViewController

@synthesize tableView           = _tableView;
@synthesize tableBannerView     = _tableBannerView;
@synthesize tableOverlayView    = _tableOverlayView;
@synthesize loadingView         = _loadingView;
@synthesize errorView           = _errorView;
@synthesize emptyView           = _emptyView;
@synthesize menuView            = _menuView;
@synthesize tableViewStyle      = _tableViewStyle;
@synthesize variableHeightRows  = _variableHeightRows;
@synthesize showTableShadows    = _showTableShadows;
@synthesize clearsSelectionOnViewWillAppear = _clearsSelectionOnViewWillAppear;
@synthesize dataSource          = _dataSource;
@synthesize resizeWhenKeyboardPresented = _resizeWhenKeyboardPresented;


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    _lastInterfaceOrientation = self.interfaceOrientation;
    _tableViewStyle = UITableViewStylePlain;
    _clearsSelectionOnViewWillAppear = YES;
    self.resizeWhenKeyboardPresented = YES;
  }

  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithStyle:(UITableViewStyle)style {
	self = [self initWithNibName:nil bundle:nil];
  if (self) {
    _tableViewStyle = style;
  }

  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc {
  _tableView.delegate = nil;
  _tableView.dataSource = nil;
  TT_RELEASE_SAFELY(_tableDelegate);
  TT_RELEASE_SAFELY(_dataSource);
  TT_RELEASE_SAFELY(_tableView);
  TT_RELEASE_SAFELY(_loadingView);
  TT_RELEASE_SAFELY(_errorView);
  TT_RELEASE_SAFELY(_emptyView);
  TT_RELEASE_SAFELY(_tableOverlayView);
  TT_RELEASE_SAFELY(_tableBannerView);
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];


  [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)createInterstitialModel {
  self.dataSource = [[[TTTableViewInterstitialDataSource alloc] init] autorelease];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString*)defaultTitleForLoading {
  return TTLocalizedString(@"Loading...", @"");
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)updateTableDelegate {
  if (!_tableView.delegate) {
    [_tableDelegate release];
    _tableDelegate = [[self createDelegate] retain];

    // You need to set it to nil before changing it or it won't have any effect
    _tableView.delegate = nil;
    _tableView.delegate = _tableDelegate;
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)addToOverlayView:(UIView*)view {
  if (!_tableOverlayView) {
    CGRect frame = [self rectForOverlayView];
    _tableOverlayView = [[UIView alloc] initWithFrame:frame];
    _tableOverlayView.autoresizesSubviews = YES;
    _tableOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth
    | UIViewAutoresizingFlexibleHeight;
    NSInteger tableIndex = [_tableView.superview.subviews indexOfObject:_tableView];
    if (tableIndex != NSNotFound) {
      [_tableView.superview addSubview:_tableOverlayView];
    }
  }

  view.frame = _tableOverlayView.bounds;
  view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [_tableOverlayView addSubview:view];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)resetOverlayView {
  if (_tableOverlayView && !_tableOverlayView.subviews.count) {
    [_tableOverlayView removeFromSuperview];
    TT_RELEASE_SAFELY(_tableOverlayView);
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)addSubviewOverTableView:(UIView*)view {
  NSInteger tableIndex = [_tableView.superview.subviews
                          indexOfObject:_tableView];
  if (NSNotFound != tableIndex) {
    [_tableView.superview addSubview:view];
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)layoutOverlayView {
  if (_tableOverlayView) {
    _tableOverlayView.frame = [self rectForOverlayView];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)layoutBannerView {
  if (_tableBannerView) {
    _tableBannerView.frame = [self rectForBannerView];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)fadeOutView:(UIView*)view {
  [view retain];
  [UIView beginAnimations:nil context:view];
  [UIView setAnimationDuration:TT_TRANSITION_DURATION];
  [UIView setAnimationDelegate:self];
  [UIView setAnimationDidStopSelector:@selector(fadingOutViewDidStop:finished:context:)];
  view.alpha = 0;
  [UIView commitAnimations];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)fadingOutViewDidStop:(NSString*)animationID finished:(NSNumber*)finished
                     context:(void*)context {
  UIView* view = (UIView*)context;
  [view removeFromSuperview];
  [view release];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hideMenuAnimationDidStop:(NSString*)animationID finished:(NSNumber*)finished
                         context:(void*)context {
  UIView* menuView = (UIView*)context;
  [menuView removeFromSuperview];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIViewController


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)loadView {
  [super loadView];
  [self tableView];

  // If this view was unloaded and is now being reloaded, and it was previously
  // showing a table banner, then redisplay that banner now.
  if (_tableBannerView) {
    UIView* savedTableBannerView = [_tableBannerView retain];
    [self setTableBannerView:nil animated:NO];
    [self setTableBannerView:savedTableBannerView animated:NO];
    [savedTableBannerView release];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)viewDidUnload {
  [super viewDidUnload];
  _tableView.delegate = nil;
  _tableView.dataSource = nil;
  TT_RELEASE_SAFELY(_tableDelegate);
  TT_RELEASE_SAFELY(_tableView);
  [_tableOverlayView removeFromSuperview];
  TT_RELEASE_SAFELY(_tableOverlayView);
  [_loadingView removeFromSuperview];
  TT_RELEASE_SAFELY(_loadingView);
  [_errorView removeFromSuperview];
  TT_RELEASE_SAFELY(_errorView);
  [_emptyView removeFromSuperview];
  TT_RELEASE_SAFELY(_emptyView);
  [_menuView removeFromSuperview];
  TT_RELEASE_SAFELY(_menuView);
  [_menuCell removeFromSuperview];
  TT_RELEASE_SAFELY(_menuCell);

  // Do not release _tableBannerView, because we have no way to recreate it on demand if
  // this view gets reloaded.
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  _viewOnScreen = YES;

  if (_lastInterfaceOrientation != self.interfaceOrientation) {
    _lastInterfaceOrientation = self.interfaceOrientation;
    [_tableView reloadData];

  } else if ([_tableView isKindOfClass:[TTTableView class]]) {
    TTTableView* tableView = (TTTableView*)_tableView;
    tableView.highlightedLabel = nil;
    tableView.showShadows = _showTableShadows;
  }

  if (_clearsSelectionOnViewWillAppear) {
    [_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:animated];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)viewDidAppear:(BOOL)animated {

  [super viewDidAppear:animated];
  if (_flags.isShowingModel) {
    [_tableView flashScrollIndicators];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)viewWillDisappear:(BOOL)animated {
  _viewOnScreen = NO;
  [super viewWillDisappear:animated];
  [self hideMenu:YES];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
  [super setEditing:editing animated:animated];
  [self.tableView setEditing:editing animated:animated];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UTViewController (TTCategory)


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)persistView:(NSMutableDictionary*)state {
  CGFloat scrollY = _tableView.contentOffset.y;
  [state setObject:@(scrollY) forKey:@"scrollOffsetY"];
  return [super persistView:state];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)restoreView:(NSDictionary*)state {
  CGFloat scrollY = [[state objectForKey:@"scrollOffsetY"] floatValue];
  if (scrollY) {
    //set to 0 if contentSize is smaller than the tableView.height
    CGFloat maxY = MAX(0, _tableView.contentSize.height - _tableView.height);
    if (scrollY <= maxY) {
      _tableView.contentOffset = CGPointMake(0, scrollY);

    } else {
      _tableView.contentOffset = CGPointMake(0, maxY);
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTModelViewController


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)beginUpdates {
  [super beginUpdates];
  [_tableView beginUpdates];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)endUpdates {
  [super endUpdates];
  [_tableView endUpdates];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)canShowModel {
  if ([_dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
    NSInteger numberOfSections = [_dataSource numberOfSectionsInTableView:_tableView];
    if (!numberOfSections) {
      return NO;

    } else if (numberOfSections == 1) {
      NSInteger numberOfRows = [_dataSource tableView:_tableView numberOfRowsInSection:0];
      return numberOfRows > 0;

    } else {
      return YES;
    }

  } else {
    NSInteger numberOfRows = [_dataSource tableView:_tableView numberOfRowsInSection:0];
    return numberOfRows > 0;
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)didLoadModel:(BOOL)firstTime {
  [super didLoadModel:firstTime];
  [_dataSource tableViewDidLoadModel:_tableView];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)didShowModel:(BOOL)firstTime {
  [super didShowModel:firstTime];
  if (![self isViewAppearing] && firstTime) {
    [_tableView flashScrollIndicators];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)showModel:(BOOL)show {
  [self hideMenu:YES];
  if (show) {
    [self updateTableDelegate];
    _tableView.dataSource = _dataSource;

  } else {
    _tableView.dataSource = nil;
  }
  [_tableView reloadData];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)showLoading:(BOOL)show {
  if (show) {
    if (!self.model.isLoaded || ![self canShowModel]) {
      NSString* title = _dataSource
      ? [_dataSource titleForLoading:NO]
      : [self defaultTitleForLoading];
      if (title.length) {
        TTActivityLabel* label =
          [[[TTActivityLabel alloc] initWithStyle:TTActivityLabelStyleWhiteBox]
           autorelease];
        label.text = title;
        label.backgroundColor = _tableView.backgroundColor;
        self.loadingView = label;
      }
    }

  } else {
    self.loadingView = nil;
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)showError:(BOOL)show {
  if (show) {
    if (!self.model.isLoaded || ![self canShowModel]) {
      NSString* title = [_dataSource titleForError:_modelError];
      NSString* subtitle = [_dataSource subtitleForError:_modelError];
      UIImage* image = [_dataSource imageForError:_modelError];
      if (title.length || subtitle.length || image) {
        TTErrorView* errorView = [[[TTErrorView alloc] initWithTitle:title
                                                            subtitle:subtitle
                                                               image:image] autorelease];
        if ([_dataSource reloadButtonForEmpty]) {
          [errorView addReloadButton];
          [errorView.reloadButton addTarget:self
                                     action:@selector(reload)
                           forControlEvents:UIControlEventTouchUpInside];
        }
        errorView.backgroundColor = _tableView.backgroundColor;

        self.errorView = errorView;

      } else {
        self.errorView = nil;
      }
      _tableView.dataSource = nil;
      [_tableView reloadData];
    }

  } else {
    self.errorView = nil;
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)showEmpty:(BOOL)show {
  if (show) {
    NSString* title = [_dataSource titleForEmpty];
    NSString* subtitle = [_dataSource subtitleForEmpty];
    UIImage* image = [_dataSource imageForEmpty];
    if (title.length || subtitle.length || image) {
      TTErrorView* errorView = [[[TTErrorView alloc] initWithTitle:title
                                                          subtitle:subtitle
                                                             image:image] autorelease];
      errorView.backgroundColor = _tableView.backgroundColor;
      self.emptyView = errorView;

    } else {
      self.emptyView = nil;
    }
    _tableView.dataSource = nil;
    [_tableView reloadData];

  } else {
    self.emptyView = nil;
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark TTModelDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)model:(id<TTModel>)model didUpdateObject:(id)object atIndexPath:(NSIndexPath*)indexPath {
  if (model == _model) {
    if (_flags.isShowingModel) {
      if ([_dataSource respondsToSelector:@selector(tableView:willUpdateObject:atIndexPath:)]) {
        NSIndexPath* newIndexPath = [_dataSource tableView:_tableView willUpdateObject:object
                                               atIndexPath:indexPath];
        if (newIndexPath) {
          if (newIndexPath.length == 1) {
            TTDCONDITIONLOG(TTDFLAG_TABLEVIEWMODIFICATIONS,
                            @"UPDATING SECTION AT %@", newIndexPath);
            NSInteger sectionIndex = [newIndexPath indexAtPosition:0];
            [_tableView reloadSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                      withRowAnimation:UITableViewRowAnimationTop];

          } else if (newIndexPath.length == 2) {
            TTDCONDITIONLOG(TTDFLAG_TABLEVIEWMODIFICATIONS, @"UPDATING ROW AT %@", newIndexPath);
            [_tableView reloadRowsAtIndexPaths:@[newIndexPath]
                              withRowAnimation:UITableViewRowAnimationTop];
          }
          [self invalidateView];

        } else {
          [_tableView reloadData];
        }
      }

    } else {
      [self refresh];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)model:(id<TTModel>)model didInsertObject:(id)object atIndexPath:(NSIndexPath*)indexPath {
  if (model == _model) {
    if (_flags.isShowingModel) {
      if ([_dataSource respondsToSelector:@selector(tableView:willInsertObject:atIndexPath:)]) {
        NSIndexPath* newIndexPath = [_dataSource tableView:_tableView willInsertObject:object
                                               atIndexPath:indexPath];
        if (newIndexPath) {
          if (newIndexPath.length == 1) {
            TTDCONDITIONLOG(TTDFLAG_TABLEVIEWMODIFICATIONS,
                            @"INSERTING SECTION AT %@", newIndexPath);
            NSInteger sectionIndex = [newIndexPath indexAtPosition:0];
            [_tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                      withRowAnimation:UITableViewRowAnimationTop];

          } else if (newIndexPath.length == 2) {
            TTDCONDITIONLOG(TTDFLAG_TABLEVIEWMODIFICATIONS, @"INSERTING ROW AT %@", newIndexPath);
            [_tableView insertRowsAtIndexPaths:@[newIndexPath]
                              withRowAnimation:UITableViewRowAnimationTop];
          }
          [self invalidateView];

        } else {
          [_tableView reloadData];
        }
      }

    } else {
      [self refresh];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)model:(id<TTModel>)model didDeleteObject:(id)object atIndexPath:(NSIndexPath*)indexPath {
  if (model == _model) {
    if (_flags.isShowingModel) {
      if ([_dataSource respondsToSelector:@selector(tableView:willRemoveObject:atIndexPath:)]) {
        NSIndexPath* newIndexPath = [_dataSource tableView:_tableView willRemoveObject:object
                                               atIndexPath:indexPath];
        if (newIndexPath) {
          if (newIndexPath.length == 1) {
            TTDCONDITIONLOG(TTDFLAG_TABLEVIEWMODIFICATIONS,
                            @"DELETING SECTION AT %@", newIndexPath);
            NSInteger sectionIndex = [newIndexPath indexAtPosition:0];
            [_tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                      withRowAnimation:UITableViewRowAnimationLeft];

          } else if (newIndexPath.length == 2) {
            TTDCONDITIONLOG(TTDFLAG_TABLEVIEWMODIFICATIONS, @"DELETING ROW AT %@", newIndexPath);
            [_tableView deleteRowsAtIndexPaths:@[newIndexPath]
                              withRowAnimation:UITableViewRowAnimationLeft];
          }
          [self invalidateView];

        } else {
          [_tableView reloadData];
        }
      }

    } else {
      [self refresh];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Public


///////////////////////////////////////////////////////////////////////////////////////////////////
- (UITableView*)tableView {
  if (nil == _tableView) {
    _tableView = [[TTTableView alloc] initWithFrame:self.view.bounds style:_tableViewStyle];
    _tableView.autoresizingMask =  UIViewAutoresizingFlexibleWidth
    | UIViewAutoresizingFlexibleHeight;

	UIColor* separatorColor = _tableViewStyle == UITableViewStyleGrouped
	? TTSTYLEVAR(tableGroupedCellSeparatorColor)
	: TTSTYLEVAR(tablePlainCellSeparatorColor);
	if (separatorColor) {
		_tableView.separatorColor = separatorColor;
	}

	_tableView.separatorStyle = _tableViewStyle == UITableViewStyleGrouped
	? TTSTYLEVAR(tableGroupedCellSeparatorStyle)
	: TTSTYLEVAR(tablePlainCellSeparatorStyle);

    UIColor* backgroundColor = _tableViewStyle == UITableViewStyleGrouped
    ? TTSTYLEVAR(tableGroupedBackgroundColor)
    : TTSTYLEVAR(tablePlainBackgroundColor);
    if (backgroundColor) {
      _tableView.backgroundColor = backgroundColor;
      self.view.backgroundColor = backgroundColor;
    }
    [self.view addSubview:_tableView];
  }
  return _tableView;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setTableView:(UITableView*)tableView {
  if (tableView != _tableView) {
    [_tableView release];
    _tableView = [tableView retain];
    if (!_tableView) {
      self.tableBannerView = nil;
      self.tableOverlayView = nil;
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setTableBannerView:(UIView*)tableBannerView {
  [self setTableBannerView:tableBannerView animated:YES];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setTableBannerView:(UIView*)tableBannerView animated:(BOOL)animated {
  if (tableBannerView != _tableBannerView) {
    if (_tableBannerView) {
      if (animated) {
        [self fadeOutView:_tableBannerView];

      } else {
        [_tableBannerView removeFromSuperview];
      }
    }

    [_tableBannerView release];
    _tableBannerView = [tableBannerView retain];

    if (_tableBannerView) {
      self.tableView.contentInset = UIEdgeInsetsMake(0, 0, TTSTYLEVAR(tableBannerViewHeight), 0);
      self.tableView.scrollIndicatorInsets = self.tableView.contentInset;
      _tableBannerView.frame = [self rectForBannerView];
      _tableBannerView.autoresizingMask = (UIViewAutoresizingFlexibleWidth
                                           | UIViewAutoresizingFlexibleTopMargin);
      [self addSubviewOverTableView:_tableBannerView];


      if (animated) {
        _tableBannerView.top += TTSTYLEVAR(tableBannerViewHeight);
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:TT_TRANSITION_DURATION];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
        _tableBannerView.top -= TTSTYLEVAR(tableBannerViewHeight);
        [UIView commitAnimations];
      }

    } else {
      self.tableView.contentInset = UIEdgeInsetsZero;
      self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setTableOverlayView:(UIView*)tableOverlayView animated:(BOOL)animated {
  if (tableOverlayView != _tableOverlayView) {
    if (_tableOverlayView) {
      if (animated) {
        [self fadeOutView:_tableOverlayView];

      } else {
        [_tableOverlayView removeFromSuperview];
      }
    }

    [_tableOverlayView release];
    _tableOverlayView = [tableOverlayView retain];

    if (_tableOverlayView) {
      _tableOverlayView.frame = [self rectForOverlayView];
      [self addToOverlayView:_tableOverlayView];
    }

    // XXXjoe There seem to be cases where this gets left disable - must investigate
    //_tableView.scrollEnabled = !_tableOverlayView;
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setDataSource:(id<TTTableViewDataSource>)dataSource {
  if (dataSource != _dataSource) {
    [_dataSource release];
    _dataSource = [dataSource retain];
    _tableView.dataSource = nil;

    self.model = dataSource.model;
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setVariableHeightRows:(BOOL)variableHeightRows {
  if (variableHeightRows != _variableHeightRows) {
    _variableHeightRows = variableHeightRows;

    // Force the delegate to be re-created so that it supports the right kind of row measurement
    _tableView.delegate = nil;
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setLoadingView:(UIView*)view {
  if (view != _loadingView) {
    if (_loadingView) {
      [_loadingView removeFromSuperview];
      TT_RELEASE_SAFELY(_loadingView);
    }
    _loadingView = [view retain];
    if (_loadingView) {
      [self addToOverlayView:_loadingView];

    } else {
      [self resetOverlayView];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setErrorView:(UIView*)view {
  if (view != _errorView) {
    if (_errorView) {
      [_errorView removeFromSuperview];
      TT_RELEASE_SAFELY(_errorView);
    }
    _errorView = [view retain];

    if (_errorView) {
      [self addToOverlayView:_errorView];

    } else {
      [self resetOverlayView];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setEmptyView:(UIView*)view {
  if (view != _emptyView) {
    if (_emptyView) {
      [_emptyView removeFromSuperview];
      TT_RELEASE_SAFELY(_emptyView);
    }
    _emptyView = [view retain];
    if (_emptyView) {
      [self addToOverlayView:_emptyView];

    } else {
      [self resetOverlayView];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id<UITableViewDelegate>)createDelegate {
  if (_variableHeightRows) {
    return [[[TTTableViewVarHeightDelegate alloc] initWithController:self] autorelease];

  } else {
    return [[[TTTableViewDelegate alloc] initWithController:self] autorelease];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)showMenu:(UIView*)view forCell:(UITableViewCell*)cell animated:(BOOL)animated {
  [self hideMenu:YES];

  _menuView = [view retain];
  _menuCell = [cell retain];

  // Insert the cell below all content subviews
  [_menuCell.contentView insertSubview:_menuView atIndex:0];

  if (animated) {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:TT_FAST_TRANSITION_DURATION];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
  }

  // Move each content subview down, revealing the menu
  for (UIView* subview in _menuCell.contentView.subviews) {
    if (subview != _menuView) {
      subview.left -= _menuCell.contentView.width;
    }
  }

  if (animated) {
    [UIView commitAnimations];
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)hideMenu:(BOOL)animated {
  if (_menuView) {
    if (animated) {
      [UIView beginAnimations:nil context:_menuView];
      [UIView setAnimationDuration:TT_FAST_TRANSITION_DURATION];
      [UIView setAnimationDelegate:self];
      [UIView setAnimationDidStopSelector:@selector(hideMenuAnimationDidStop:finished:context:)];
    }

    for (UIView* view in _menuCell.contentView.subviews) {
      if (view != _menuView) {
        view.left += _menuCell.contentView.width;
      }
    }

    if (animated) {
      [UIView commitAnimations];

    } else {
      [_menuView removeFromSuperview];
    }

    TT_RELEASE_SAFELY(_menuView);
    TT_RELEASE_SAFELY(_menuCell);
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)didSelectObject:(id)object atIndexPath:(NSIndexPath*)indexPath {

}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)shouldOpenURL:(NSString*)URL {
  return YES;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)didBeginDragging {
  [self hideMenu:YES];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)didEndDragging {
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (CGRect)rectForOverlayView {
  return [_tableView frame];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (CGRect)rectForBannerView {
  CGRect tableFrame = [_tableView frame];
  const CGFloat bannerViewHeight = TTSTYLEVAR(tableBannerViewHeight);
  return CGRectMake(tableFrame.origin.x,
                    (tableFrame.origin.y + tableFrame.size.height) - bannerViewHeight,
                    tableFrame.size.width, bannerViewHeight);
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)invalidateModel {
  [super invalidateModel];

  // Renew the tableView delegate when the model is refreshed.
  // Otherwise the delegate will be retained the model.

  // You need to set it to nil before changing it or it won't have any effect
  _tableView.delegate = nil;
  [self updateTableDelegate];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)resizeForKeyboard:(NSNotification*)aNotification {
  if (!_viewOnScreen)
    return;
  
  BOOL up = aNotification.name == UIKeyboardWillShowNotification;
  
  if (_keyboardVisible == up)
    return;
  

  _keyboardVisible = up;
  NSDictionary* userInfo = [aNotification userInfo];
  NSTimeInterval animationDuration;
  UIViewAnimationCurve animationCurve;
  CGRect keyboardEndFrame;
  [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
  [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
  [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrame];
  
  [UIView animateWithDuration:animationDuration delay:0 options:animationCurve
                   animations:^{
                     CGRect keyboardFrame = [self.view convertRect:keyboardEndFrame toView:nil];
                     self.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0,  up ? keyboardFrame.size.height : 0, 0.0);
                   }
                   completion:NULL];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setResizeWhenKeyboardPresented:(BOOL)observesKeyboard {
  if (observesKeyboard != _resizeWhenKeyboardPresented) {
    _resizeWhenKeyboardPresented = observesKeyboard;
    
    if (_resizeWhenKeyboardPresented) {
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizeForKeyboard:) name:UIKeyboardWillShowNotification object:nil];
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizeForKeyboard:) name:UIKeyboardWillHideNotification object:nil];
    } else {
      [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
      [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    }
  }
}


@end
