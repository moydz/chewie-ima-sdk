import 'package:chewie/src/chewie_player.dart';
import 'package:chewie/src/helpers/adaptive_controls.dart';
import 'package:chewie/src/notifiers/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';

class PlayerWithControls extends StatefulWidget {
  const PlayerWithControls({super.key, required this.controller, required this.adTagUrl});
  final ChewieController controller;
  final String adTagUrl;

  // IMA sample tag for a single skippable inline video ad. See more IMA sample
  // tags at https://developers.google.com/interactive-media-ads/docs/sdks/html5/client-side/tags

  @override
  State<PlayerWithControls> createState() => _PlayerWithControlsState();
}

class _PlayerWithControlsState extends State<PlayerWithControls> {
  late ChewieController chewieController;
  // The AdsLoader instance exposes the request ads method.
  late final AdsLoader _adsLoader;
  // AdsManager exposes methods to control ad playback and listen to ad events.
  AdsManager? _adsManager;

  // Whether the widget should be displaying the content video. The content
  bool _shouldShowContentVideo = true;

  @override
  void initState() {
    super.initState();
    chewieController=widget.controller;
    chewieController.addListener(() {
      if (chewieController.videoPlayerController.value.isCompleted) {
        _adsLoader.contentComplete();
        setState(() {});
      }
    });
  }

  Future<void> _requestAds(AdDisplayContainer container) {
    _adsLoader = AdsLoader(
      container: container,
      onAdsLoaded: (OnAdsLoadedData data) {
        final AdsManager manager = data.manager;
        _adsManager = data.manager;

        manager.setAdsManagerDelegate(AdsManagerDelegate(
          onAdEvent: (AdEvent event) {
            debugPrint('OnAdEvent: ${event.type}');
            switch (event.type) {
              case AdEventType.loaded:
                manager.start();
              case AdEventType.contentPauseRequested:
                _pauseContent();
              case AdEventType.contentResumeRequested:
                _resumeContent();
              case AdEventType.allAdsCompleted:
                manager.destroy();
                _adsManager = null;
              case AdEventType.clicked:
              case AdEventType.complete:
            }
          },
          onAdErrorEvent: (AdErrorEvent event) {
            debugPrint('AdErrorEvent: ${event.error.message}');
            _resumeContent();
          },
        ));

        manager.init();
      },
      onAdsLoadError: (AdsLoadErrorData data) {
        debugPrint('OnAdsLoadError: ${data.error.message}');
        _resumeContent();
      },
    );

    return _adsLoader.requestAds(AdsRequest(adTagUrl: widget.adTagUrl));
  }

  Future<void> _resumeContent() {
    setState(() {
      _shouldShowContentVideo = true;
    });
    return chewieController.play();
  }

  Future<void> _pauseContent() {
    setState(() {
      _shouldShowContentVideo = false;
    });
    return chewieController.pause();
  }

  // #docregion ad_and_content_players
  late final AdDisplayContainer _adDisplayContainer = AdDisplayContainer(
    onContainerAdded: (AdDisplayContainer container) {
      // Ads can't be requested until the `AdDisplayContainer` has been added to
      // the native View hierarchy.
      _requestAds(container);
    },
  );

  @override
  void dispose() {
    super.dispose();
    chewieController.dispose();
    _adsManager?.destroy();
  }

  @override
  Widget build(BuildContext context) {
    //final ChewieController chewieController = ChewieController.of(context);

    double calculateAspectRatio(BuildContext context) {
      final size = MediaQuery.of(context).size;
      final width = size.width;
      final height = size.height;

      return width > height ? width / height : height / width;
    }

    Widget buildControls(
        BuildContext context,
        ChewieController chewieController,
        ) {
      return chewieController.showControls
          ? chewieController.customControls ?? const AdaptiveControls()
          : const SizedBox();
    }

    Widget buildPlayerWithControls(
        ChewieController chewieController,
        BuildContext context,
        ) {
      return Stack(
        children: <Widget>[
          if (chewieController.placeholder != null)
            chewieController.placeholder!,
          InteractiveViewer(
            transformationController: chewieController.transformationController,
            maxScale: chewieController.maxScale,
            panEnabled: chewieController.zoomAndPan,
            scaleEnabled: chewieController.zoomAndPan,
            child: Center(
              child: AspectRatio(
                  aspectRatio: chewieController.aspectRatio ??
                      chewieController.videoPlayerController.value.aspectRatio,
                  child: Stack(
                    children: <Widget>[
                      // The display container must be on screen before any Ads can be
                      // loaded and can't be removed between ads. This handles clicks for
                      // ads.
                      _adDisplayContainer,
                      if (_shouldShowContentVideo)
                        VideoPlayer(chewieController.videoPlayerController),
                    ],
                  )
              ),
            ),
          ),
          if (chewieController.overlay != null) chewieController.overlay!,
          if (Theme.of(context).platform != TargetPlatform.iOS)
            Consumer<PlayerNotifier>(
              builder: (
                  BuildContext context,
                  PlayerNotifier notifier,
                  Widget? widget,
                  ) =>
                  Visibility(
                    visible: !notifier.hideStuff,
                    child: AnimatedOpacity(
                      opacity: notifier.hideStuff ? 0.0 : 0.8,
                      duration: const Duration(
                        milliseconds: 250,
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black54),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
            ),
          if(_shouldShowContentVideo)
            if (!chewieController.isFullScreen && _shouldShowContentVideo)
              buildControls(context, chewieController)
            else
              SafeArea(
                bottom: false,
                child: buildControls(context, chewieController),
              ),
        ],
      );
    }

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Center(
            child: SizedBox(
              height: constraints.maxHeight,
              width: constraints.maxWidth,
              child: AspectRatio(
                aspectRatio: calculateAspectRatio(context),
                child: buildPlayerWithControls(chewieController, context),
              ),
            ),
          );
        });
  }
}
