import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:mixin_logger/mixin_logger.dart';

import '../settings/settings_view.dart';

import 'package:win_toast/win_toast.dart';
import 'package:tray_manager/tray_manager.dart';

class PomodoroView extends StatefulWidget {
  @override
  _PomodoroViewState createState() => _PomodoroViewState();
}

class _PomodoroViewState extends State<PomodoroView>
    with WidgetsBindingObserver, TrayListener {
  Timer? _timer;
  int _remainingTime = 25 * 60; // 25 minutes in seconds
  bool _isRunning = false;
  bool _isBreak = false;
  bool _isForeground = false;
  int _workTime = 25 * 60;
  int _breakTime = 5 * 60;

  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();

    trayManager.addListener(this);

    WinToast.instance().initialize(
      aumId: 'one.mixin.WinToastExample',
      displayName: 'Dragondoro',
      iconPath: 'assets/images/tray.ico',
      clsid: '936C39FC-6BBC-4A57-B8F8-7C627E401B2F',
    );

    // Ajouter cet observateur au cycle de vie de l'application
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    trayManager.removeListener(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isForeground = true;
        _playerStop();
        break;
      case AppLifecycleState.hidden:
        _isForeground = false;
        break;
      case AppLifecycleState.inactive:
        _isForeground = false;
        break;
      default:
    }
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {}

  void _startStopTimer() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingTime > 0) {
            _remainingTime--;
          } else {
            _timer?.cancel();
            _isRunning = false;
            if (!_isBreak) {
              // Start break period
              _isBreak = true;
              _remainingTime = _breakTime; // 5 minutes in seconds
              Process.run('cmd', [
                '/c',
                'powershell',
                '-command',
                'rundll32.exe user32.dll,LockWorkStation'
              ]);
              _startStopTimer();
            } else {
              // End break period
              _isBreak = false;
              _remainingTime = _workTime; // 25 minutes in seconds

              // Show notification
              // Repeat notification every 10 seconds until the app is in the foreground

              for (var i in List.generate(6, (index) => index)) {
                showNotification();
                Future.delayed(const Duration(seconds: 10));
              }

              // Play sound
              _playSound();
            }
          }
        });
      });
    }
    setState(() {
      _isRunning = !_isRunning;
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _playSound() async {
    String audioPath = 'audio/coding.mp3';
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource(audioPath));
  }

  showNotification() async {
    try {
      // Lock Windows screen through PowerShell launching a command
      Process.run('cmd', [
        '/c',
        'powershell',
        '-command',
        'rundll32.exe user32.dll,LockWorkStation'
      ]);

      // Wait for 5 seconds

      await Future.delayed(const Duration(seconds: 5));

      await WinToast.instance().showToast(
        toast: Toast(
          duration: ToastDuration.short,
          launch: 'action=viewConversation&conversationId=9813',
          children: [
            ToastChildAudio(source: ToastAudioSource.defaultSound),
            ToastChildVisual(
              binding: ToastVisualBinding(
                children: [
                  ToastVisualBindingChildText(
                    text: 'Dragondoro',
                    id: 1,
                  ),
                  ToastVisualBindingChildText(
                    text: 'Time to work!',
                    id: 2,
                  ),
                ],
              ),
            ),
            ToastChildActions(children: [
              ToastAction(
                content: "Close",
                arguments: "close_argument",
              )
            ]),
          ],
        ),
      );
    } catch (error, stacktrace) {
      i('showTextToast error: $error, $stacktrace');
    }
  }

  _playerStop() {
    player.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
          // Add a button to restart the timer
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _timer?.cancel();
                _isRunning = false;
                _isBreak = false;
                _remainingTime = 2;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _isBreak ? 'Break' : 'Work',
              style: TextStyle(fontSize: 24),
            ),
            Text(
              _formatTime(_remainingTime),
              style: const TextStyle(fontSize: 48),
            ),
            ElevatedButton(
              onPressed: _startStopTimer,
              child: Text(_isRunning ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}
