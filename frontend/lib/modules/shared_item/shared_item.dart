import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app_scaffold.dart';
import '../../common/currency_service.dart';
import '../../common/socket_service.dart';
import '../../common/form_input/input_fields.dart';
import './shared_item_class.dart';
import './shared_item_state.dart';
import './shared_item_service.dart';
import './shared_item_owner_class.dart';
import '../user_auth/current_user_state.dart';


class SharedItem extends StatefulWidget {
  @override
  _SharedItemState createState() => _SharedItemState();
}

class _SharedItemState extends State<SharedItem> {
  List<String> _routeIds = [];
  SocketService _socketService = SocketService();
  InputFields _inputFields = InputFields();
  CurrencyService _currency = CurrencyService();
  SharedItemService _sharedItemService = SharedItemService();

  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic?> _filters = {
    'title': '',
    //'tags': '',
    'lng': -999.0,
    'lat': -999.0,
    'maxMeters': '8000',
    'fundingRequired_min': '',
    'fundingRequired_max': '',
  };
  bool _loading = false;
  String _message = '';
  bool _canLoadMore = false;
  int _lastPageNumber = 1;
  int _itemsPerPage = 25;
  bool _skipCurrentLocation = false;
  bool _locationLoaded = false;

  List<SharedItemClass> _sharedItems = [];
  bool _firstLoadDone = false;
  var _selectedSharedItem = {
    'id': '',
  };

  List<Map<String, String>> _selectOptsMaxMeters = [
    {'value': '500', 'label': '5 min walk'},
    {'value': '1500', 'label': '15 min walk'},
    {'value': '3500', 'label': '15 min bike'},
    {'value': '8000', 'label': '15 min car'},
  ];

  @override
  void initState() {
    super.initState();

    _routeIds.add(_socketService.onRoute('searchSharedItems', callback: (String resString) {
      var res = jsonDecode(resString);
      var data = res['data'];
      if (data['valid'] == 1) {
        if (data.containsKey('sharedItems')) {
          _sharedItems = [];
          for (var sharedItem in data['sharedItems']) {
            _sharedItems.add(SharedItemClass.fromJson(sharedItem));
          }
          if (_sharedItems.length == 0) {
            _message = 'No results found.';
          }
        } else {
          _message = 'Error.';
        }
      } else {
        _message = data['msg'].length > 0 ? data['msg'] : 'Error.';
      }
      setState(() {
        _loading = false;
      });
    }));

    _routeIds.add(_socketService.onRoute('removeSharedItem', callback: (String resString) {
      var res = jsonDecode(resString);
      var data = res['data'];
      if (data['valid'] == 1) {
        _searchSharedItems();
      } else {
        _message = data['msg'].length > 0 ? data['msg'] : 'Error.';
      }
      setState(() {
        _loading = false;
      });
    }));

    WidgetsBinding.instance.addPostFrameCallback((_){
      _init();
    });
  }

  @override
  void dispose() {
    _socketService.offRouteIds(_routeIds);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    checkFirstLoad();

    var currentUserState = context.watch<CurrentUserState>();

    var columnsCreate = [
      Align(
        alignment: Alignment.topRight,
        child: ElevatedButton(
          onPressed: () {
            Provider.of<SharedItemState>(context, listen: false).clearSharedItem();
            context.go('/shared-item-save');
          },
          child: Text('Post New Item'),
        ),
      ),
      SizedBox(height: 10),
    ];

    return AppScaffoldComponent(
      body: ListView(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.only(top: 20, bottom: 30, left: 10, right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...columnsCreate,
                  Align(
                    alignment: Alignment.center,
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            child: _inputFields.inputText(_filters, 'title', hint: 'title',
                              label: 'Filter by Title', debounceChange: 1000, onChange: (String val) {
                              _searchSharedItems();
                            }),
                          ),
                          SizedBox(
                            width: 200,
                            child: _inputFields.inputSelect(_selectOptsMaxMeters, _filters, 'maxMeters',
                              label: 'Range', onChanged: (String val) {
                              _searchSharedItems();
                            }),
                          ),
                          SizedBox(
                            width: 200,
                            child: _inputFields.inputNumber(_filters, 'fundingRequired_min', hint: '\$1000',
                              label: 'Minimum Funding Needed', debounceChange: 1000, onChange: (double? val) {
                              _searchSharedItems();
                            }),
                          ),
                          SizedBox(
                            width: 200,
                            child: _inputFields.inputNumber(_filters, 'fundingRequired_max', hint: '\$500',
                              label: 'Maximum Funding Needed', debounceChange: 1000, onChange: (double? val) {
                              _searchSharedItems();
                            }),
                          ),
                        ]
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: _buildSharedItemResults(context, currentUserState),
                  ),
                ]
              )
            )
          )
        ]
      )
    );
  }

  void checkFirstLoad() {
    if (!_firstLoadDone && _locationLoaded) {
      _firstLoadDone = true;
      _searchSharedItems();
    }
  }

  void _init() async {
    if (!_skipCurrentLocation) {
      List<dynamic> _userLngLat = await Provider.of<CurrentUserState>(context, listen: false).getUserLocation();
      _filters['lat'] =  _userLngLat.elementAt(1);
      _filters['lng'] =  _userLngLat.elementAt(0);
      _locationLoaded = true;
      checkFirstLoad();
    }
  }

  Widget _buildMessage(BuildContext context) {
    if (_message.length > 0) {
      return Container(
        padding: EdgeInsets.only(top: 20, bottom: 20, left: 10, right: 10),
        child: Text(_message),
      );
    }
    return SizedBox.shrink();
  }

  _buildSharedItem(SharedItemClass sharedItem, BuildContext context, var currentUserState) {
    var buttons = [];
    if (currentUserState.isLoggedIn && sharedItem.currentOwnerUserId == currentUserState.currentUser.id) {
      buttons = [
        ElevatedButton(
          onPressed: () {
            Provider.of<SharedItemState>(context, listen: false).setSharedItem(sharedItem);
            context.go('/shared-item-save');
          },
          child: Text('Edit'),
        ),
        SizedBox(width: 10),
        // SizedBox(width: 10),
        // ElevatedButton(
        //   onPressed: () {
        //     _socketService.emit('removeSharedItem', { 'id': sharedItem.id });
        //   },
        //   child: Text('Delete'),
        //   style: ElevatedButton.styleFrom(
        //     primary: Theme.of(context).errorColor,
        //   ),
        // ),
        // SizedBox(width: 10),
      ];
    }
    if (currentUserState.isLoggedIn && sharedItem.currentOwnerUserId != currentUserState.currentUser.id) {
      buttons += [
        ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedSharedItem = {
                'id': sharedItem.id!,
              };
            });
          },
          child: Text('Borrow'),
          //style: ElevatedButton.styleFrom(
          //  primary: Theme.of(context).successColor,
          //),
        ),
        SizedBox(width: 10),
      ];
    }

    var columnsDistance = [];
    if (sharedItem.xDistanceKm >= 0) {
      columnsDistance = [
        Text('${sharedItem.xDistanceKm.toStringAsFixed(1)} km away'),
        SizedBox(height: 10),
      ];
    }

    var columnsSelected = [];
    // if (sharedItem.id == _selectedSharedItem['id']) {
    //   columnsSelected = [
    //     Text('${sharedItem.xOwner['email']}'),
    //     SizedBox(height: 10),
    //   ];
    // }

    String currentPriceString = _currency.Format(sharedItem.currentPrice, sharedItem.currency!);

    Map<String, String> texts;
    Map<String, dynamic> paymentInfo;
    // int newOwners = (sharedItem.pledgedOwners >= sharedItem.minOwners) ? sharedItem.pledgedOwners + 1 : sharedItem.minOwners;
    // paymentInfo = _sharedItemService.GetPayments(sharedItem.currentPrice!,
    //   sharedItem.monthsToPayBack!, newOwners, sharedItem.maintenancePerYear!);
    // texts = _sharedItemService.GetTexts(paymentInfo['downPerPersonWithFee']!,
    //   paymentInfo['monthlyPaymentWithFee']!, paymentInfo['monthsToPayBack']!, sharedItem.currency);
    paymentInfo = _sharedItemService.GetPayments(sharedItem.currentPrice!,
      sharedItem.monthsToPayBack!, sharedItem.maxOwners, sharedItem.maintenancePerYear!);
    texts = _sharedItemService.GetTexts(paymentInfo['downPerPersonWithFee']!,
      paymentInfo['monthlyPaymentWithFee']!, paymentInfo['monthsToPayBack']!, sharedItem.currency);
    String perPersonMaxOwners = "${texts['perPerson']} with max owners (${sharedItem.maxOwners})";

    String fundingRequired = "${_currency.Format(sharedItem.fundingRequired, sharedItem.currency!)} funding required";
    List<Widget> colsInvest = [];
    if (sharedItem.fundingRequired! > 0) {
      colsInvest = [
        Text('${fundingRequired}'),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            String id = sharedItem.sharedItemOwner_current.id;
            context.go('/shared-item-owner-save?sharedItemId=${sharedItem.id}&id=${id}');
          },
          child: Text('Invest'),
        ),
        SizedBox(height: 10),
      ];
    }

    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sharedItem.imageUrls.length <= 0 ?
            Image.asset('assets/images/no-image-available-icon-flat-vector.jpeg', height: 300, width: double.infinity, fit: BoxFit.cover,)
              :Image.network(sharedItem.imageUrls![0], height: 300, width: double.infinity, fit: BoxFit.cover),
          SizedBox(height: 5),
          Text(sharedItem.title!,
            style: Theme.of(context).textTheme.headline2,
          ),
          SizedBox(height: 5),
          //Text('Tags: ${sharedItem.tags.join(', ')}'),
          //SizedBox(height: 5),
          ...columnsDistance,
          // Text('${currentPriceString}'),
          // Text('${(sharedItem.maxOwners - sharedItem.pledgedOwners)} spots left'),
          // Text('${sharedItem.minOwners} to ${sharedItem.maxOwners} owners'),
          // SizedBox(height: 10),
          Text("${perPersonMaxOwners}"),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              String id = sharedItem.sharedItemOwner_current.id;
              context.go('/shared-item-owner-save?sharedItemId=${sharedItem.id}&id=${id}');
            },
            child: Text('Co-Buy'),
          ),
          SizedBox(height: 10),
          ...colsInvest,
          Text('${sharedItem.description}'),
          SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...buttons,
            ]
          ),
          SizedBox(height: 10),
          ...columnsSelected,
          SizedBox(height: 10),
        ]
      )
    );
  }

  _buildSharedItemResults(BuildContext context, CurrentUserState currentUserState) {
    if (_sharedItems.length > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: <Widget> [
              ..._sharedItems.map((sharedItem) => _buildSharedItem(sharedItem, context, currentUserState) ).toList(),
            ]
          ),
        ]
      );
    }
    return _buildMessage(context);
  }

  void _searchSharedItems({int lastPageNumber = 0}) {
    if(mounted){
      setState(() {
        _loading = true;
        _message = '';
        _canLoadMore = false;
      });
    }
    var currentUser = Provider.of<CurrentUserState>(context, listen: false).currentUser;
    if (lastPageNumber != 0) {
      _lastPageNumber = lastPageNumber;
    } else {
      _lastPageNumber = 1;
    }
    var data = {
      //'page': _lastPageNumber,
      'skip': (_lastPageNumber - 1) * _itemsPerPage,
      'limit': _itemsPerPage,
      //'sortKey': '-created_at',
      //'tags': [],
      // 'withOwnerInfo': 1,
      'lngLat': [_filters['lng'], _filters['lat']],
      'maxMeters': _filters['maxMeters'],
      'withOwnerUserId': currentUser.id,
    };
    List<String> keys = ['title', 'fundingRequired_min', 'fundingRequired_max'];
    for (var key in keys) {
      if (_filters[key] != null && _filters[key] != '') {
        data[key] = _filters[key]!;
      }
    }
    //if (_filters['tags'] != '') {
    //  data['tags'] = [ _filters['tags'] ];
    //}
    _socketService.emit('searchSharedItems', data);
  }

}