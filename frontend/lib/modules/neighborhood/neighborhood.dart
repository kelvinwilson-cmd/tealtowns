import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scaffold.dart';
import '../../common/buttons.dart';
import '../../common/config_service.dart';
import '../../common/layout_service.dart';
import '../../common/link_service.dart';
import '../../common/socket_service.dart';
import '../../common/style.dart';
import './neighborhood_class.dart';
import './neighborhood_state.dart';
import './neighborhood_journey.dart';
import './neighborhood_journey_service.dart';
import '../event/weekly_event_class.dart';
import '../shared_item/shared_item_class.dart';
import '../user_auth/current_user_state.dart';

class Neighborhood extends StatefulWidget {
  String uName;
  int limitCount;
  int itemCount;
  Neighborhood({this.uName = '', this.limitCount = 250, this.itemCount = 3,});

  @override
  _NeighborhoodState createState() => _NeighborhoodState();
}

class _NeighborhoodState extends State<Neighborhood> {
  Buttons _buttons = Buttons();
  ConfigService _configService = ConfigService();
  LayoutService _layoutService = LayoutService();
  LinkService _linkService = LinkService();
  NeighborhoodJourneyService _neighborhoodJourneyService = NeighborhoodJourneyService();
  List<String> _routeIds = [];
  SocketService _socketService = SocketService();
  Style _style = Style();

  NeighborhoodClass _neighborhood = NeighborhoodClass.fromJson({});
  int _weeklyEventsCount = 0;
  int _sharedItemsCount = 0;
  int _usersCount = 0;
  int _eventUsersCount = 0;
  List<WeeklyEventClass> _weeklyEvents = [];
  List<SharedItemClass> _sharedItems = [];
  bool _inited = false;
  bool _loading = false;
  List<Map<String, dynamic>> _belongingSteps = [];
  List<Map<String, dynamic>> _sustainableSteps = [];
  bool _showFullNeighborhoodJourney = false;

  @override
  void initState() {
    super.initState();

    _routeIds.add(_socketService.onRoute('GetNeighborhoodByUName', callback: (String resString) {
      var res = jsonDecode(resString);
      var data = res['data'];
      if (data['valid'] == 1) {
        _neighborhood = NeighborhoodClass.fromJson(data['neighborhood']);
        _weeklyEventsCount = data['weeklyEventsCount'];
        _sharedItemsCount = data['sharedItemsCount'];
        _usersCount = data['usersCount'];
        _eventUsersCount = data['eventUsersCount'];
        _weeklyEvents = [];
        for (var i = 0; i < data['weeklyEvents'].length; i++) {
          _weeklyEvents.add(WeeklyEventClass.fromJson(data['weeklyEvents'][i]));
        }
        _sharedItems = [];
        for (var i = 0; i < data['sharedItems'].length; i++) {
          _sharedItems.add(SharedItemClass.fromJson(data['sharedItems'][i]));
        }
        _belongingSteps = _neighborhoodJourneyService.BelongingStepsWithComplete(_eventUsersCount, _weeklyEventsCount, _sharedItemsCount);
        _sustainableSteps = _neighborhoodJourneyService.SustainableSteps();
        setState(() {
          _neighborhood = _neighborhood;
          _weeklyEventsCount = _weeklyEventsCount;
          _sharedItemsCount = _sharedItemsCount;
          _usersCount = _usersCount;
          _eventUsersCount = _eventUsersCount;
          _weeklyEvents = _weeklyEvents;
          _sharedItems = _sharedItems;
          _belongingSteps = _belongingSteps;
          _sustainableSteps = _sustainableSteps;
          _loading = false;
        });
      } else {
        context.go('/neighborhoods');
      }
    }));

    _routeIds.add(_socketService.onRoute('SaveUserNeighborhood', callback: (String resString) {
      var res = jsonDecode(resString);
      var data = res['data'];
      if (data['valid'] == 1) {
        GetNeighborhood();
      }
    }));
  }

  @override
  void dispose() {
    _socketService.offRouteIds(_routeIds);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_inited) {
      _inited = true;
      GetNeighborhood();
    }
    Map<String, dynamic> config = _configService.GetConfig();

    if (_loading) {
      return AppScaffoldComponent(
        listWrapper: true,
        body: LinearProgressIndicator(),
      );
    }

    double lng = _neighborhood.location.coordinates[0];
    double lat = _neighborhood.location.coordinates[1];
    List<Widget> colsWeeklyEvents = [];
    if (_weeklyEventsCount > 0) {
      List<Widget> elements = [];
      for (var i = 0; i < _weeklyEvents.length; i++) {
        WeeklyEventClass weeklyEvent = _weeklyEvents[i];
        elements.add(
          Column(
            children: [
              weeklyEvent.imageUrls.length <= 0 ?
                Image.asset('assets/images/shared-meal.jpg', height: 300, width: double.infinity, fit: BoxFit.cover,)
                : Image.network(weeklyEvent.imageUrls![0], height: 300, width: double.infinity, fit: BoxFit.cover),
              SizedBox(height: 10),
              _buttons.Link(context, '${weeklyEvent.title}', '/we/${weeklyEvent.uName}'),
            ]
          )
        );
        if (i >= widget.itemCount) {
          break;
        }
      }
      colsWeeklyEvents = [
        _layoutService.WrapWidth(elements, width: 300),
        SizedBox(height: 10),
        _buttons.LinkElevated(context, 'View All Events', '/weekly-events?lng=${lng}&lat=${lat}'),
      ];
    } else {
      colsWeeklyEvents = [
        _buttons.LinkElevated(context, 'Create Event', '/weekly-event-save', checkLoggedIn: true),
      ];
    }

    List<Widget> colsSharedItems = [];
    if (_sharedItemsCount > 0) {
      List<Widget> elements = [];
      for (var i = 0; i < _sharedItems.length; i++) {
        SharedItemClass sharedItem = _sharedItems[i];
        elements.add(
          Column(
            children: [
              sharedItem.imageUrls.length <= 0 ?
                Image.asset('assets/images/no-image-available-icon-flat-vector.jpeg', height: 300, width: double.infinity, fit: BoxFit.cover,)
                : Image.network(sharedItem.imageUrls![0], height: 300, width: double.infinity, fit: BoxFit.cover),
              SizedBox(height: 10),
              _buttons.Link(context, '${sharedItem.title}', '/shared-item-owner-save?sharedItemId=${sharedItem.id}'),
            ]
          )
        );
        if (i >= widget.itemCount) {
          break;
        }
      }
      colsSharedItems = [
        _style.Text1('${_sharedItemsCount} Shared Items', size: 'large'),
        _style.SpacingH('medium'),
        _layoutService.WrapWidth(elements, width: 300),
        SizedBox(height: 10),
        _buttons.LinkElevated(context, 'View All Shared Items', '/own?lng=${lng}&lat=${lat}'),
      ];
    }

    List<Widget> colsFullJourney = [];
    if (_showFullNeighborhoodJourney) {
      colsFullJourney = [
        SizedBox(height: 10),
        NeighborhoodJourney(),
      ];
    }

    List<Widget> colsJoin = [];
    var currentUserState = Provider.of<CurrentUserState>(context, listen: false);
    if (!currentUserState.isLoggedIn || 
      (currentUserState.isLoggedIn && (!_neighborhood.userNeighborhood.containsKey('status') ||
      _neighborhood.userNeighborhood['status'] != 'default'))) {
      colsJoin = [
        ElevatedButton(
          onPressed: () {
            if (!currentUserState.isLoggedIn) {
              _linkService.Go('/n/${_neighborhood.uName}', context, currentUserState: currentUserState);
            } else {
              SaveUserNeighborhood(_neighborhood.id);
            }
          },
          child: Text('Join Neighborhood'),
        ),
        SizedBox(height: 10),
      ];
    }

    return AppScaffoldComponent(
      listWrapper: true,
      body: Column(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _style.Text1('${_neighborhood.title}', size: 'xlarge'),
          ...colsJoin,
          _style.SpacingH('medium'),
          // _style.Text1('Continue your neighborhood journey; your Weekly Challenge is:',),
          // _style.SpacingH('medium'),
          NeighborhoodJourney(belongingSteps: _belongingSteps, sustainableSteps: _sustainableSteps,
            currentStepOnly: true, showTitles: false,),
          _style.SpacingH('medium'),
          // _buttons.Link(context, 'View Full Neighborhood Journey', '/neighborhood-journey'),
          TextButton(
            onPressed: () {
              _showFullNeighborhoodJourney = !_showFullNeighborhoodJourney;
              setState(() { _showFullNeighborhoodJourney = _showFullNeighborhoodJourney; });
            },
            child: Text(_showFullNeighborhoodJourney ? 'Hide Full Neighborhood Journey' : 'View Full Neighborhood Journey'),
          ),
          ...colsFullJourney,
          _style.SpacingH('large'),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _style.Text1('${_weeklyEventsCount} Weekly Events', size: 'large'),
                _style.SpacingH('medium'),
                ...colsWeeklyEvents,
              ]
            )
          ),
          _style.SpacingH('large'),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...colsSharedItems,
              ]
            )
          ),
          _style.SpacingH('large'),
          _style.Text1('${_usersCount} neighbors thus far'),
          _style.SpacingH('medium'),
          _style.Text1('Share your neighborhood with your neighbors', size: 'large'),
          _style.SpacingH('medium'),
          QrImageView(
            data: '${config['SERVER_URL']}/n/${_neighborhood.uName}',
            version: QrVersions.auto,
            size: 200.0,
          ),
          _style.SpacingH('medium'),
          Text('${config['SERVER_URL']}/n/${_neighborhood.uName}'),
          _style.SpacingH('medium'),
          // TODO - sustainability and connections
        ]
      )
    );
  }

  void GetNeighborhood() {
    setState(() { _loading = true; });
    String userId = Provider.of<CurrentUserState>(context, listen: false).isLoggedIn ?
      Provider.of<CurrentUserState>(context, listen: false).currentUser.id : '';
    var data = {
      'uName': widget.uName,
      'withWeeklyEvents': 1,
      'withSharedItems': 1,
      'withConnections': 1,
      'withSustainability': 1,
      'withUsersCount': 1,
      'withEventUsersCount': 1,
      'limitCount': widget.limitCount,
      'userId': userId,
    };
    _socketService.emit('GetNeighborhoodByUName', data);
  }

  void SaveUserNeighborhood(String neighborhoodId) {
    String userId = Provider.of<CurrentUserState>(context, listen: false).isLoggedIn ?
      Provider.of<CurrentUserState>(context, listen: false).currentUser.id : '';
    var data = {
      'userNeighborhood': {
        'neighborhoodId': neighborhoodId,
        'userId': userId,
        'status': 'default',
      },
    };
    _socketService.emit('SaveUserNeighborhood', data);
    Provider.of<NeighborhoodState>(context, listen: false).ClearUserNeighborhoods();
  }
}
