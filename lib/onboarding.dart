import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:testfilm/main.dart';

class Onboarding extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: OnboardingPage(),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  @override
  _OnboardingPageState createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  late Database database;
  bool isOnboarded = false;
  late PageController _pageController;
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;
  String? token; // Добавляем переменную для токена
  bool check_token = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _initDatabase();
    _checkOnboardingStatus();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _getToken();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  Future<void> _getToken() async {
    token = await getTokenFromDatabase(); // Получаем токен сохраненный на устройстве
    if (token != null) {
      // Выводим полученный токен
      print('Отримано токен: $token');

      // Проверка токена на валидность через API
      final response = await http.get(Uri.parse('https://64.176.66.91/check_token.php?token=$token'));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == 'true') {
          // Токен действителен, запускаем приложение
          runApp(MyApp());
        } else {
          // Токен недействителен, выводим ошибку
          Fluttertoast.showToast(
            msg: responseData['desc'] ?? 'Помилка перевірки токена',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
        setState(() {
          check_token = true;
        });
      } else {
        // Обработка ошибки, если запрос завершился неудачей
        Fluttertoast.showToast(
          msg: 'Помилка мережі: ${response.statusCode}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        setState(() {
          check_token = true;
        });
      }
    } else {
      print('Токен не знайдено');
      setState(() {
        check_token = true;
      });
    }
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



  Future<void> _initDatabase() async {
    database = await openDatabase(
      join(await getDatabasesPath(), 'app_data.db'),
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE settings(id INTEGER PRIMARY KEY, isOnboarded INTEGER)',
        );
        await db.execute(
          'CREATE TABLE user(id INTEGER PRIMARY KEY, token TEXT)',
        );
      },
      version: 1,
    );
  }


  Future<void> _checkOnboardingStatus() async {
    final List<Map<String, dynamic>> maps = await database.query('settings');
    if (maps.isNotEmpty) {
      isOnboarded = maps[0]['isOnboarded'] == 1;
    } else {
      await database.insert('settings', {'isOnboarded': 0});
    }
    setState(() {});
  }

  Future<void> _setOnboarded() async {
    await database.update(
      'settings',
      {'isOnboarded': 1},
      where: 'id = ?',
      whereArgs: [1],
    );
    setState(() {
      isOnboarded = true;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {


    return isOnboarded ? _buildLoginScreen(context) : _buildOnboardingScreen();
  }

  Widget _buildOnboardingScreen() {
    _animationController.forward();

    return Stack(
      children: [
        // Основное содержимое OnboardingScreen
        OnboardingScreen(),

        // Если check_token == false, добавляем размытие и индикатор загрузки
        if (!check_token) // Замените check_token на вашу переменную проверки токена
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Настройте степень размытия
            child: Container(
              color: Colors.black.withOpacity(0.33), // Белый фон с 10% непрозрачностью
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }


  Widget OnboardingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "MF057 | Bluetooth Terminal",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _animationController.reverse().then((_) => _animationController.forward());
              });
            },
            children: [
              _buildPage("Інноваційний блютуз термінал", "Надійний блютуз термінал, з'єднуйтесь з пристроєм, відправляйте команди."),
              _buildPage("Зручний інтерфейс", "Зручно керуйте своїми пристроями, створіть обліковий запис та зберігайте свої девайси."),
              _buildPage("Підтримка", "Ми постійно оновлюємо додаток, намагаючись покращити його для користувачів."),
            ],
          ),
          // Если check_token == false, добавляем размытие и индикатор загрузки

        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: () {
          _setOnboarded();
        },
        child: Icon(Icons.arrow_forward),
      ),
      bottomNavigationBar: _buildPageIndicator(),
    );
  }

  Widget OnboardingScreenBlured() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "MF057 | Bluetooth Terminal",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _animationController.reverse().then((_) => _animationController.forward());
              });
            },
            children: [
              _buildPage("Інноваційний блютуз термінал", "Надійний блютуз термінал, з'єднуйтесь з пристроєм, відправляйте команди."),
              _buildPage("Зручний інтерфейс", "Зручно керуйте своїми пристроями, створіть обліковий запис та зберігайте свої девайси."),
              _buildPage("Підтримка", "Ми постійно оновлюємо додаток, намагаючись покращити його для користувачів."),
            ],
          ),
          // Если check_token == false, добавляем размытие и индикатор загрузки

        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: () {
          _setOnboarded();
        },
        child: Icon(Icons.arrow_forward),
      ),
      bottomNavigationBar: _buildPageIndicator(),
    );
  }



  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.all(4.0),
            width: _currentPage == index ? 8 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index ? Colors.black : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPage(String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            SizedBox(height: 20),
            FadeTransition(
              opacity: _animation,
              child: Column(
                children: [
                  Image.asset(
                    'assets/icon512.png', // Путь к изображению
                    height: 100, // Задайте нужную высоту
                    fit: BoxFit.contain, // Настройте отображение
                  ),
                  Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(height: 20),
            FadeTransition(
              opacity: _animation,
              child: Text(description, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginScreen(BuildContext buildContext) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Авторизація | MF057",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("Вхід", style: TextStyle(fontSize: 24)),
                      SizedBox(height: 20),
                      _buildInputField("Email", _emailController),
                      SizedBox(height: 16),
                      _buildInputField("Пароль", _passwordController, obscureText: true),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _loginUser();
                          },
                          child: Text(
                            "Увійти",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            primary: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                // Переход к регистрации
                Navigator.push(
                  buildContext,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => RegistrationPage(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0); // Начальная позиция (снизу)
                      const end = Offset.zero; // Конечная позиция (центр)
                      const curve = Curves.easeInOut; // Кривая анимации

                      // Определяем анимацию
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);

                      // Создаем анимацию
                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
                    },
                    transitionDuration: Duration(milliseconds: 333), // Длительность анимации

                  ),
                );


              },
              child: Text(
                "Реєстрація",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginUser() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Fluttertoast.showToast(msg: "Заповніть усі дані");
      return;
    }

    final response = await http.get(Uri.parse('https://64.176.66.91/login_user.php?email=$email&password=$password'));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['success'] == 'true') {
        String token = jsonResponse['token'];
        await _saveToken(token); // Сохраняем токен
        Fluttertoast.showToast(msg: "Успішна авторизація!\nТокен: $token",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        runApp(MyApp());
        // Здесь вы можете перенаправить пользователя на главную страницу или другую страницу
      } else {
        Fluttertoast.showToast(msg: jsonResponse['desc']);
      }
    } else {
      Fluttertoast.showToast(msg: "Ошибка при авторизации.");
    }
  }


  Widget _buildInputField(String label, TextEditingController controller, {bool obscureText = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200], // Серый фон
        borderRadius: BorderRadius.circular(12), // Закругленные углы
      ),
      child: TextField(
        controller: controller, // Установка контроллера
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.black), // Цвет метки
          floatingLabelStyle: TextStyle(color: Colors.black.withOpacity(0.85)), // Цвет плавающей метки
          border: InputBorder.none, // Убираем нижнюю линию
          contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0), // Внутренние отступы
        ),
      ),
    );
  }

  Future<void> _saveToken(String token) async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS user(id INTEGER PRIMARY KEY, token TEXT)',
    );

    // Проверяем, существует ли уже токен
    final List<Map<String, dynamic>> results = await database.query('user');

    if (results.isNotEmpty) {
      // Если токен существует, обновляем его
      await database.update(
        'user',
        {'token': token},
        where: 'id = ?',
        whereArgs: [results.first['id']],
      );
    } else {
      // Если токена нет, вставляем новый
      await database.insert('user', {'token': token});
    }
  }




}

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r'^[^@]+@[^@]+\.[^@]+$', // Простое регулярное выражение для проверки email
    );
    return emailRegex.hasMatch(email);
  }


  Future<void> _registerUser(BuildContext buildContext) async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();


    if(email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      Fluttertoast.showToast(msg: "Заповніть усі дані");
    }

    // Проверка на совпадение паролей
    if (password != confirmPassword) {
      Fluttertoast.showToast(msg: "Паролі не збігаються");
      return;
    }

    if (!isValidEmail(email)) {
      Fluttertoast.showToast(msg: "Будь ласка, введіть дійсну електронну адресу");
      return;
    }

    final response = await http.get(Uri.parse('https://64.176.66.91/create_user.php?email=$email&password=$password'));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['success'] == 'true') {
        Fluttertoast.showToast(
          msg: "Реєстрація успішна! Увійдіть",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        Navigator.pop(buildContext);

        //    Navigator.pop(context); // Возврат к странице авторизации
      } else {
        // Выводим сообщение об ошибке
        Fluttertoast.showToast(msg: jsonResponse['desc']);
      }
    } else {
      Fluttertoast.showToast(msg: "Ошибка при регистрации.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Реєстрація | MF057",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        automaticallyImplyLeading: false,
      /*  leading: IconButton(
          icon: Icon(Icons.arrow_downward), // Стрелка вниз
          onPressed: () {
            Navigator.pop(context); // Возврат к предыдущему экрану
          },
        ), */
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("Реєстрація", style: TextStyle(fontSize: 24)),
                      SizedBox(height: 20),
                      _buildInputField("Email", _emailController),
                      SizedBox(height: 16),
                      _buildInputField("Пароль", _passwordController, obscureText: true),
                      SizedBox(height: 16),
                      _buildInputField("Повторіть пароль", _confirmPasswordController, obscureText: true),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _registerUser(context), // Используйте стрелочную функцию
                          child: Text(
                            "Створити обліковий запис",
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            primary: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                // Возврат к странице авторизации
                Navigator.pop(context);
              },
              child: Text(
                "Я вже зареєстрований",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool obscureText = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200], // Серый фон
        borderRadius: BorderRadius.circular(12), // Закругленные углы
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelStyle: TextStyle(color: Colors.black.withOpacity(0.85)), // Цвет плавающей метки
          border: InputBorder.none, // Убираем нижнюю линию
          contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0), // Внутренние отступы
        ),
      ),
    );
  }
}

