import 'dart:async';

import 'package:Openbook/models/post.dart';
import 'package:Openbook/models/user.dart';
import 'package:Openbook/pages/home/pages/post/widgets/post_comment/post_comment.dart';
import 'package:Openbook/provider.dart';
import 'package:Openbook/services/httpie.dart';
import 'package:Openbook/services/toast.dart';
import 'package:Openbook/services/user.dart';
import 'package:Openbook/widgets/icon.dart';
import 'package:Openbook/widgets/post/post.dart';
import 'package:Openbook/widgets/post/widgets/post-actions/widgets/post_action_comment.dart';
import 'package:Openbook/widgets/post/widgets/post-actions/widgets/post_action_react.dart';
import 'package:Openbook/widgets/post/widgets/post_comments/post_comments.dart';
import 'package:Openbook/widgets/progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:loadmore/loadmore.dart';

class OBTimelinePosts extends StatefulWidget {
  final OBTimelinePostsController controller;

  OBTimelinePosts(
      {this.controller,});

  @override
  OBTimelinePostsState createState() {
    return OBTimelinePostsState();
  }
}

class OBTimelinePostsState extends State<OBTimelinePosts> {
  List<Post> _posts;
  bool _needsBootstrap;
  UserService _userService;
  ToastService _toastService;
  StreamSubscription _loggedInUserChangeSubscription;
  ScrollController _postsScrollController;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  bool _loadingFinished;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) widget.controller.attach(this);
    _posts = [];
    _needsBootstrap = true;
    _loadingFinished = false;
    _postsScrollController = ScrollController();
  }

  @override
  void dispose() {
    super.dispose();
    _loggedInUserChangeSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    var provider = OpenbookProvider.of(context);
    _userService = provider.userService;
    _toastService = provider.toastService;

    if (_needsBootstrap) {
      _bootstrap();
      _needsBootstrap = false;
    }

    return _buildTimeline();
  }

  Widget _buildTimeline() {
    return RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _onRefresh,
        child: LoadMore(
            whenEmptyLoad: false,
            isFinish: _loadingFinished,
            delegate: OBHomePostsLoadMoreDelegate(),
            child: ListView.builder(
                physics: AlwaysScrollableScrollPhysics(),
                controller: _postsScrollController,
                padding: EdgeInsets.all(0),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  var post = _posts[index];
                  return OBPost(
                    post,
                  );
                }),
            onLoadMore: _loadMorePosts));
  }

  void scrollToTop() {
    _postsScrollController.animateTo(
      0.0,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 300),
    );
  }

  void addPostToTop(Post post) {
    setState(() {
      this._posts.insert(0, post);
    });
  }

  void _bootstrap() async {
    _loggedInUserChangeSubscription =
        _userService.loggedInUserChange.listen(_onLoggedInUserChange);
  }

  Future<void> _onRefresh() {
    return _refreshPosts(areFirstPosts: false);
  }

  void _onLoggedInUserChange(User newUser) async {
    if (newUser == null) return;
    _refreshPosts();
    _loggedInUserChangeSubscription.cancel();
  }

  Future<void> _refreshPosts({areFirstPosts = true}) async {
    try {
      Post.clearCache();
      User.clearNavigationCache();
      _posts =
          (await _userService.getTimelinePosts(areFirstPosts: areFirstPosts))
              .posts;
      _setPosts(_posts);
      _setLoadingFinished(false);
    } on HttpieConnectionRefusedError catch (error) {
      _onConnectionRefusedError(error);
    } catch (error) {
      _onUnknownError(error);
      rethrow;
    }
  }

  Future<bool> _loadMorePosts() async {
    var lastPost = _posts.last;
    var lastPostId = lastPost.id;
    try {
      var morePosts =
          (await _userService.getTimelinePosts(maxId: lastPostId)).posts;

      if (morePosts.length == 0) {
        _setLoadingFinished(true);
      } else {
        setState(() {
          _posts.addAll(morePosts);
        });
      }
      return true;
    } on HttpieConnectionRefusedError catch (error) {
      _onConnectionRefusedError(error);
    } catch (error) {
      _onUnknownError(error);
      rethrow;
    }

    return false;
  }

  void _setPosts(List<Post> posts) {
    setState(() {
      _posts = posts;
    });
  }

  void _setLoadingFinished(bool loadingFinished) {
    setState(() {
      _loadingFinished = loadingFinished;
    });
  }

  void _onConnectionRefusedError(HttpieConnectionRefusedError error) {
    _toastService.error(message: 'No internet connection', context: context);
  }

  void _onUnknownError(Error error) {
    _toastService.error(message: 'Unknown error', context: context);
  }
}

class OBTimelinePostsController {
  OBTimelinePostsState _homePostsState;

  /// Register the OBHomePostsState to the controller
  void attach(OBTimelinePostsState homePostsState) {
    assert(homePostsState != null, 'Cannot attach to empty state');
    _homePostsState = homePostsState;
  }

  void addPostToTop(Post post) {
    _homePostsState.addPostToTop(post);
  }

  void scrollToTop() {
    _homePostsState.scrollToTop();
  }

  bool isAttached() {
    return _homePostsState != null;
  }
}

class OBHomePostsLoadMoreDelegate extends LoadMoreDelegate {
  const OBHomePostsLoadMoreDelegate();

  @override
  Widget buildChild(LoadMoreStatus status,
      {LoadMoreTextBuilder builder = DefaultLoadMoreTextBuilder.english}) {
    String text = builder(status);

    if (status == LoadMoreStatus.fail) {
      return Container(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.refresh),
            SizedBox(
              width: 10.0,
            ),
            Text('Tap to retry loading posts.')
          ],
        ),
      );
    }
    if (status == LoadMoreStatus.idle) {
      // No clue why is this even a state.
      return SizedBox();
    }
    if (status == LoadMoreStatus.loading) {
      return Container(
          child: Center(
        child: OBProgressIndicator(),
      ));
    }
    if (status == LoadMoreStatus.nomore) {
      return SizedBox();
    }

    return Text(text);
  }
}