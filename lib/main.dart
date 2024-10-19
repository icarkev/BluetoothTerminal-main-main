import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

import 'onboarding.dart';

final GlobalKey<_DeviceTerminalState> deviceTerminalKey = GlobalKey<_DeviceTerminalState>();

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(Onboarding());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BluetoothScanner(),
    );
  }
}

class BluetoothScanner extends StatefulWidget {
  @override
  _BluetoothScannerState createState() => _BluetoothScannerState();
}

class _BluetoothScannerState extends State<BluetoothScanner>
    with SingleTickerProviderStateMixin {
  List<BluetoothDevice> bluetoothDevices = [];
  List<BluetoothDevice> bleDevices = [];
  bool isScanning = false;
  BluetoothCharacteristic? currentCharacteristic;
  StreamSubscription? _lastValueSubscription;

  late TabController _tabController;
  int _selectedIndex = 0; // Переменная для отслеживания выбранного экрана

  String? _token;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _tabController = TabController(length: 2, vsync: this);
    requestPermissions();
    _getToken();
  }

  // Асинхронная функция для получения токена
  Future<void> _getToken() async {
    print('stored token');
    _token = await getTokenFromDatabase();
    print(_token);
    if (_token != null) {
      print('Токен получен: $_token');
      // Вы можете добавить дополнительные действия с токеном здесь
    } else {
      print('Токен не найден');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      //Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      Fluttertoast.showToast(
        msg: "Дозвіл надано",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } else {
      Fluttertoast.showToast(
        msg: "Не всі дозволи надані",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void startScan() async {
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      Fluttertoast.showToast(
        msg: "Bluetooth не підтримується на цьому девайсі.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      Fluttertoast.showToast(
        msg: "Увімкніть Bluetooth.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    /*var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      Fluttertoast.showToast(
        msg: "Разрешение на доступ к геолокации не предоставлено.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }*/

    setState(() {
      isScanning = true;
      bluetoothDevices.clear();
      bleDevices.clear();
    });

    FlutterBluePlus.startScan(timeout: Duration(seconds: 30));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        for (ScanResult result in results) {
          final device = result.device;

          if (device.platformName.contains('BLE') || device.platformName.contains('LE')) {
            if (!bleDevices.any((d) => d.remoteId == device.remoteId)) {
              bleDevices.add(device);
            }
          } else {
            if (!bluetoothDevices.any((d) => d.remoteId == device.remoteId)) {
              bluetoothDevices.add(device);
            }
          }
        }
      });
    });

    Future.delayed(Duration(seconds: 30), () async {
      await FlutterBluePlus.stopScan();
      setState(() {
        isScanning = false;
      });

      Fluttertoast.showToast(
        msg: "Сканування завершено. Знайдено: ${bluetoothDevices.length + bleDevices.length} пристроїв",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      if (bluetoothDevices.isEmpty && bleDevices.isEmpty) {
        Fluttertoast.showToast(
          msg: "Пристрої не знайдено. Повторіть пошук",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    });
  }

  Future<void> SimulateConnectToDevice(BluetoothDevice device) async {
    try {
      // Имитация задержки для тестового подключения
      await Future.delayed(Duration(seconds: 1));

      // Успешное подключение (имитация)
      Fluttertoast.showToast(
        msg: "З'єднано з ${device.platformName.isEmpty ? 'Тестовий пристрій' : device.platformName}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      ///DeviceTerminal._messages.add('Помилка: неможливо знайти характеристики для передачі або отримання даних.');


      // Переход в терминал устройства
      Navigator.push(
        this.context,
        MaterialPageRoute(
          builder: (context) => DeviceTerminal(key: deviceTerminalKey, device: device, isTestMode: true),
        ),
      );

    } catch (e) {
      // Если что-то пошло не так (например, ошибка в имитации)
      Fluttertoast.showToast(
        msg: "Помилка з'єднання: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Подключаемся к устройству
      await device.connect();
      Fluttertoast.showToast(
        msg: "З'єднано з ${device.platformName}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Получаем список услуг устройства
      List<BluetoothService> services = await device.discoverServices();

      // Находим нужную характеристику (замените UUID на ваш)
      BluetoothCharacteristic? characteristic;
      for (var service in services) {
        for (var c in service.characteristics) {
          if (c.properties.notify) {
            characteristic = c; // Сохраняем характеристику для уведомлений
            break;
          }
        }
        if (characteristic != null) break; // Найдено уведомление, выходим из цикла
      }

      deviceTerminalKey.currentState?.clearMessages();

      // Отписываемся от предыдущих уведомлений, если они существуют
      if (currentCharacteristic != null) {
        await currentCharacteristic!.setNotifyValue(false);
      }

      stopListen();

      // Подписываемся на уведомления
      if (characteristic != null) {
        currentCharacteristic = characteristic; // Обновляем текущую характеристику

        _lastValueSubscription = characteristic.lastValueStream.listen((value) {
          String receivedMessage = ascii.decode(value); // Декодируем полученное сообщение
          String deviceName = device.platformName;

          deviceTerminalKey.currentState?.AddMsg(deviceName, receivedMessage);
          print("Received: $receivedMessage");
        });

        // Уведомляем об этом
        await characteristic.setNotifyValue(true);
      }

      // Переход в терминал устройства
      Navigator.push(
        this.context,
        MaterialPageRoute(
          builder: (context) => DeviceTerminal(key: deviceTerminalKey, device: device),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Помилка з'єднання: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void stopListen() {
    _lastValueSubscription?.cancel();
    _lastValueSubscription = null; // Очистите ссылку на подписку
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBluetoothScreen() {
    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
          //    buildTestDeviceList(),
              // Отображение списка Bluetooth устройств
              buildDeviceList(bluetoothDevices), // Bluetooth Devices
              // Отображение списка BLE устройств
              buildDeviceList(bleDevices), // BLE Devices
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 15.0, left: 5, right: 5), // Отступы для кнопки
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: isScanning ? Colors.black : Colors.white,
              backgroundColor: isScanning ? Colors.white : Colors.black,
            ),
            onPressed: isScanning ? null : startScan,
            child: Text(isScanning ? 'Сканування...' : 'Почати скан'),
          ),
        ),
      ],
    );
  }


  Widget _buildMyDevicesScreen() {

    // Здесь ваш код для отображения "Мои устройства"
    return MyDevicesScreen(token: _token!);
  }

  Widget _buildSettingsScreen() {
    // Здесь ваш код для отображения "Мои устройства"
    return Center(child: Text('Налаштування'));
  }

  @override
  Widget build(BuildContext context) {
    Widget _getBody() {
      switch (_selectedIndex) {
        case 0:

          return _buildBluetoothScreen(); // Ваш экран с Bluetooth
        case 1:
          return _buildMyDevicesScreen(); // Экран "Мои устройства"
        case 2:
          return _buildSettingsScreen(); // Экран "Настройки"
        default:
          return Container();
      }
    }

    AppBar _getAppBar() {
      return AppBar(
        title:  _selectedIndex == 0 ? Text('Welcome to MF057') : null,
        bottom: _selectedIndex == 0 // Добавьте условие для отображения TabBar только на нужном экране
            ? TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Bluetooth'),
            Tab(text: 'BLE'),
          ],
        )
            : null, // Если это не экран Bluetooth, то TabBar не будет отображаться
      );
    }

    return Scaffold(
      appBar: _getAppBar(), // Убедитесь, что здесь вызывается метод с круглыми скобками
      body: _getBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Головна',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.devices),
            label: 'Мої девайси',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Налаштування',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  Future<String?> getTokenFromDatabase() async {
    final database = await openDatabase(join(await getDatabasesPath(), 'app_data.db'));
    try {
      final List<Map<String, dynamic>> results = await database.query('user');
      if (results.isNotEmpty) {
        return results.first['token'] as String?;
      }
    } catch (e) {
      print('Error retrieving token: $e');
    }
    return null;
  }

  Widget buildTestDeviceList() {
    List<BluetoothDevice> testDevices = [
      BluetoothDevice(
        remoteId: DeviceIdentifier("11:00:00:00:00:00"),  // Уникальный ID устройства
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: testDevices.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(testDevices[index].platformName.isEmpty
                    ? 'Тестовий пристрій'
                    : testDevices[index].platformName),
                subtitle: Text(testDevices[index].remoteId.toString()),
                onTap: () => SimulateConnectToDevice(testDevices[index]),
              );
            },
          ),
        ),
        /*Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text('Симуляція пшуку завершена'),
        ), */
      ],
    );
  }


  Widget buildDeviceList(List<BluetoothDevice> devices) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(devices[index].platformName.isEmpty
                    ? 'Невідомий пристрій'
                    : devices[index].platformName),
                subtitle: Text(devices[index].remoteId.toString()),
                onTap: () => connectToDevice(devices[index]),
              );
            },
          ),
        ),
        if (isScanning) Padding(padding: EdgeInsets.only(bottom: 20), child: CircularProgressIndicator()),
      ],
    );
  }
}

class DeviceTerminal extends StatefulWidget {
  final BluetoothDevice device;
  final bool isTestMode; // Флаг для тестового режима

  DeviceTerminal({Key? key, required this.device, this.isTestMode = false}) : super(key: key);


  @override
  _DeviceTerminalState createState() => _DeviceTerminalState();
}

class _DeviceTerminalState extends State<DeviceTerminal> {
  TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // Добавляем ScrollController

  _DeviceTerminalState();

  List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    // Отправляем сообщение при инициализации
    _initializeMessages();
  }

  void AddMsg(String deviceName, String msg) {
    if(deviceName == widget.device.platformName) {
      setState(() {
        _messages.add("[$deviceName]: " + msg);
      });
    }
  }




  void _initializeMessages() {
    String initialMessage = 'Connected - ${widget.device.platformName.isEmpty ? 'TST001' : widget.device.platformName}';
    setState(() {
      _messages.add(initialMessage);
    });
  }

  // Функция для добавления устройства с автоматическим получением токена
  void _addDeviceToList(String uuid, String platformName) async {
    // Получаем токен из базы данных
    String? token = await getTokenFromDatabase();

    // Проверка, был ли успешно получен токен
    if (token == null) {
      Fluttertoast.showToast(
        msg: 'Токен не найден.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

  //  final response = await http.get(Uri.parse('https://64.176.66.91/create_user.php?email=$email&password=$password'));

    if(platformName == '') {
      platformName = 'test';
    }
    // URL вашего API
    final url = Uri.parse('https://64.176.66.91/add_device.php?uuid=$uuid&platformName=$platformName&token=$token');

    print(url);
    try {
      // Параметры запроса
      final response = await http.get(
        url.replace(queryParameters: {
          'uuid': uuid,
          'platformName': platformName,
          'token': token, // Используем полученный токен
        }),
      );

      // Проверка на успешный запрос
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == 'true') {
          print('Устройство добавлено успешно: ${response.body}');
          Fluttertoast.showToast(
            msg: 'Устройство успешно добавлено',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        } else {
          print('Ошибка при добавлении устройства: ${response.body}');
          Fluttertoast.showToast(
            msg: responseData['desc'] ?? 'Ошибка при добавлении устройства',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      } else {
        print('Ошибка при добавлении устройства: ${response.statusCode}');
        Fluttertoast.showToast(
          msg: 'Ошибка сервера: ${response.statusCode}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      // Обработка ошибок запроса
      print('Ошибка запроса: $e');
      Fluttertoast.showToast(
        msg: 'Ошибка запроса: $e',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

// Функция для получения токена из локальной базы данных устройства
  Future<String?> getTokenFromDatabase() async {
    final database = await openDatabase(join(await getDatabasesPath(), 'app_data.db'));
    try {
      final List<Map<String, dynamic>> results = await database.query('user');
      if (results.isNotEmpty) {
        return results.first['token'] as String?;
      }
    } catch (e) {
      print('Error retrieving token: $e');
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Термінал: ${widget.device.platformName.isEmpty ? 'Тестовий пристрій' : widget.device.platformName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Разделяет элементы по краям
              children: [
            /*    Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Выровняем текст по левому краю
                  children: [
                    Text(
                      'ID пристрою: ${widget.device.remoteId}',
                      style: TextStyle(fontSize: 11),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Статус: Конектед',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),*/
                ElevatedButton(
                  onPressed: null, // Логика nuдля добавления устройства
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blueGrey.withOpacity(0.5), // Цвет фона кнопки
                    onPrimary: Colors.white, // Цвет текста кнопки
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0), // Установить радиус углов
                    ),
                  ),
                  child: Row(
                    children: [
                     // SizedBox(width: 5),
                      Text('DeviceID: ${widget.device.remoteId}'), // Текст кнопки
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _addDeviceToList(
                    widget.device.remoteId.toString(),
                    widget.device.platformName,
                  ),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.blueGrey, // Цвет фона кнопки
                    onPrimary: Colors.white, // Цвет текста кнопки
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0), // Установить радиус углов
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.devices), // Иконка плюса
                      SizedBox(width: 10),
                      Text('Зберегти'), // Текст кнопки
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF000000).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: ListTile(
                          title: Text(
                            _messages[index],
                            style: TextStyle(color: Colors.greenAccent),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Column(
              children: [
                Container(
                  height: 50,
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'Введіть меседж',
                      labelStyle: TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: BorderSide(color: Colors.black.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.0),
                        borderSide: BorderSide(color: Colors.black.withOpacity(0.3)),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sendMessage,
                        style: ElevatedButton.styleFrom(
                          primary: Colors.black,
                          onPrimary: Colors.white,
                          minimumSize: Size(0, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                        ),
                        child: Text('Надіслати'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // Логика отправки сообщения
  void _sendMessage() {
    FocusScope.of(this.context).unfocus();
    String message = _controller.text;
    if (message.isNotEmpty) {


      // В зависимости от режима, выполняем логику
      if (widget.isTestMode) {

        setState(() {
          _messages.add('Ви: $message'); // Добавляем отправленное сообщение в список
          _controller.clear();
        });

        // Имитация получения ответа от устройства
        Future.delayed(Duration(seconds: 1), () {
          setState(() {
            _messages.add('${widget.device.platformName.isEmpty ? 'Тестовий пристрій' : widget.device.platformName}: Відповідь на "$message"');
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        });
      } else {
        // Реальное получение ответа от устройства (например, через Bluetooth)
        _sendRealCommand(message);
      }
    }
  }

  String bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
  }


  // Отправка реальной команды устройству
  void _sendRealCommand(String command) async {
    try {
      // Поиск характеристики для связи с устройством
      List<BluetoothService> services = await widget.device.discoverServices();
      BluetoothCharacteristic? writeCharacteristic;
      BluetoothCharacteristic? readCharacteristic;

      // Поиск нужных характеристик (чтение и запись)
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            writeCharacteristic = characteristic;
          }
          if (characteristic.properties.read) {
            readCharacteristic = characteristic;
          }
        }
      }

      if (writeCharacteristic == null || readCharacteristic == null) {
        setState(() {
          _messages.add('Помилка: неможливо знайти характеристики для передачі або отримання даних.');
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
        return;
      }

      // Отправка команды
      List<int> bytesToSend = command.codeUnits; // Преобразуем команду в байты
      await writeCharacteristic!.write(bytesToSend);
      setState(() {
        _messages.add('Ви: $command'); // Добавляем отправленное сообщение в список
      });

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Чтение ответа
      List<int> responseBytes = await readCharacteristic!.read();
      String response = String.fromCharCodes(responseBytes); // Преобразуем байты в строку

      String response2 = utf8.decode(responseBytes); // Преобразуем байты в строку с использованием utf8
      String responseHex = bytesToHex(responseBytes);
      String responseText = ascii.decode(responseBytes);

      setState(() {
      //  _messages.add('[${widget.device.platformName}]: $responseText'); // Добавляем ответ от устройства в список
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    } catch (e) {
      setState(() {
        _messages.add('Помилка відправлення: $e');
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  void clearMessages() {

  }

}



class MyDevicesScreen extends StatefulWidget {
  final String token;

  const MyDevicesScreen({Key? key, required this.token}) : super(key: key);

  @override
  _MyDevicesScreenState createState() => _MyDevicesScreenState();
}

class _MyDevicesScreenState extends State<MyDevicesScreen> {
  List<Map<String, String>> devices = [];
  bool isLoading = true; // Индикатор загрузки

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  // Функция для получения списка устройств с сервера
  Future<void> _fetchDevices() async {
    final url = Uri.parse('https://64.176.66.91/my_devices.php?token=${widget.token}');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == 'true') {
          setState(() {
            devices = (data['devices'] as List).map<Map<String, String>>((device) {
              return {
                'uuid': device['uuid'],
                'device_name': device['device_name'],
              };
            }).toList();
            isLoading = false;
          });
        } else {
          _showToast('Ошибка: ${data['desc']}');
        }
      } else {
        _showToast('Ошибка при получении данных: ${response.statusCode}');
      }
    } catch (e) {
      _showToast('Ошибка запроса: $e');
      print(e);
    }
  }



  // Функция для подключения к устройству
  void _connectToDevice(String uuid) {
    // Логика для подключения к устройству через connectToDevice
    BluetoothDevice device = BluetoothDevice(
      remoteId: DeviceIdentifier(uuid),  // Уникальный ID устройства
    ); // пример создания объекта устройства
    connectToDevice(device);
  }

  // Функция для вывода сообщений
  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Мої девайси'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Показать индикатор загрузки
          : devices.isEmpty
          ? Center(child: Text('Немає зареєстрованих пристроїв'))
          : ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            title: Text(device['device_name'] ?? 'Неизвестное устройство'),
            subtitle: Text('UUID: ${device['uuid']}'),
            onTap: () => _connectToDevice(device['uuid'] ?? ''),
          );
        },
      ),
    );
  }
}




Future<void> connectToDevice(BluetoothDevice device) async {
  try {
    // Подключаемся к устройству
    await device.connect();
    Fluttertoast.showToast(
      msg: "З'єднано з ${device.platformName}",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );

    // Получаем список услуг устройства
    List<BluetoothService> services = await device.discoverServices();

    // Находим нужную характеристику (замените UUID на ваш)
    BluetoothCharacteristic? characteristic;
    for (var service in services) {
      for (var c in service.characteristics) {
        if (c.properties.notify) {
          characteristic = c; // Сохраняем характеристику для уведомлений
          break;
        }
      }
      if (characteristic != null) break; // Найдено уведомление, выходим из цикла
    }

    deviceTerminalKey.currentState?.clearMessages();
/*
    // Отписываемся от предыдущих уведомлений, если они существуют
    if (currentCharacteristic != null) {
      await currentCharacteristic!.setNotifyValue(false);
    }

    stopListen();

    // Подписываемся на уведомления
    if (characteristic != null) {
      currentCharacteristic = characteristic; // Обновляем текущую характеристику

      _lastValueSubscription = characteristic.lastValueStream.listen((value) {
        String receivedMessage = ascii.decode(value); // Декодируем полученное сообщение
        String deviceName = device.platformName;

        deviceTerminalKey.currentState?.AddMsg(deviceName, receivedMessage);
        print("Received: $receivedMessage");
      });

      // Уведомляем об этом
      await characteristic.setNotifyValue(true);
    } */

    // Переход в терминал устройства
    Navigator.push(
      context as BuildContext,
      MaterialPageRoute(
        builder: (context) => DeviceTerminal(key: deviceTerminalKey, device: device),
      ),
    );
  } catch (e) {
    Fluttertoast.showToast(
      msg: "Помилка з'єднання: $e",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }
}