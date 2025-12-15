import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smartagriapp/state/themeprovier.dart';

class WeatherContent extends StatefulWidget {
  const WeatherContent({super.key});

  @override
  State<WeatherContent> createState() => _WeatherContentState();
}

class _WeatherContentState extends State<WeatherContent> {
  final String apiKey = '175757e9410f65219720dcbf0cb15436';
  final String baseUrl = 'https://api.openweathermap.org/data/2.5';

  TextEditingController cityController = TextEditingController(text: 'Lahore');
  bool isLoading = false;
  String errorMessage = '';
  Map<String, dynamic>? weatherData;
  List<dynamic>? forecastData;

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    if (cityController.text.isEmpty) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final currentWeatherUrl =
          '$baseUrl/weather?q=${cityController.text}&appid=$apiKey&units=metric';
      final currentResponse = await http.get(Uri.parse(currentWeatherUrl));

      if (currentResponse.statusCode == 200) {
        weatherData = json.decode(currentResponse.body);

        final forecastUrl =
            '$baseUrl/forecast?q=${cityController.text}&appid=$apiKey&units=metric&cnt=40';
        final forecastResponse = await http.get(Uri.parse(forecastUrl));

        if (forecastResponse.statusCode == 200) {
          final forecastJson = json.decode(forecastResponse.body);
          forecastData = forecastJson['list'];
        } else {
          _createDummyForecastData();
        }
      } else {
        final errorBody = json.decode(currentResponse.body);
        throw Exception(errorBody['message'] ?? 'Failed to load weather data');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
      });
      _createDummyData();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _createDummyData() {
    final now = DateTime.now();
    weatherData = {
      'name': cityController.text,
      'main': {'temp': 22.0},
      'weather': [
        {'main': 'Clear', 'icon': '01d'},
      ],
      'sys': {'country': 'PK'},
    };

    _createDummyForecastData();
  }

  void _createDummyForecastData() {
    final now = DateTime.now();
    final forecast = <Map<String, dynamic>>[];

    for (int i = 0; i < 40; i++) {
      final date = now.add(Duration(hours: i * 3));
      final temp = 20 + (i % 5).toDouble();
      forecast.add({
        'dt': date.millisecondsSinceEpoch ~/ 1000,
        'main': {'temp': temp},
        'weather': [
          {
            'main': i % 3 == 0
                ? 'Clear'
                : i % 3 == 1
                ? 'Clouds'
                : 'Rain',
            'icon': i % 3 == 0
                ? '01d'
                : i % 3 == 1
                ? '03d'
                : '10d',
          },
        ],
      });
    }

    forecastData = forecast;
  }

  String _getWeatherIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }

  String _getWeatherCondition(String mainCondition) {
    switch (mainCondition.toLowerCase()) {
      case 'clear':
        return 'Sunny';
      case 'clouds':
        return 'Cloudy';
      case 'rain':
      case 'drizzle':
        return 'Rainy';
      case 'snow':
        return 'Snowy';
      case 'thunderstorm':
        return 'Stormy';
      case 'smoke':
        return 'Smoky';
      case 'mist':
      case 'fog':
      case 'haze':
        return 'Misty';
      default:
        return mainCondition;
    }
  }

  List<Map<String, dynamic>> _getDailyForecast() {
    if (forecastData == null || forecastData!.isEmpty) return [];

    final dailyForecasts = <String, Map<String, dynamic>>{};

    for (final forecast in forecastData!) {
      final dt = forecast['dt'] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(dt * 1000);
      final dayKey = DateFormat('yyyy-MM-dd').format(date);

      if (!dailyForecasts.containsKey(dayKey)) {
        dailyForecasts[dayKey] = {
          'date': date,
          'temp_min': double.infinity,
          'temp_max': double.negativeInfinity,
          'conditions': <String>[],
          'icon': forecast['weather'][0]['icon'],
          'main_condition': forecast['weather'][0]['main'],
        };
      }

      final tempValue = forecast['main']['temp'];
      final temp = tempValue is num ? tempValue.toDouble() : 0.0;
      final currentDay = dailyForecasts[dayKey]!;

      if (temp < currentDay['temp_min']) {
        currentDay['temp_min'] = temp;
      }
      if (temp > currentDay['temp_max']) {
        currentDay['temp_max'] = temp;
      }

      final condition = forecast['weather'][0]['main'];
      if (condition is String) {
        currentDay['conditions'].add(condition);
      }
    }

    final result = dailyForecasts.entries.map((entry) {
      final conditions = entry.value['conditions'] as List<String>;
      final mostCommonCondition = conditions.isNotEmpty
          ? _getMostCommonCondition(conditions)
          : entry.value['main_condition'] as String;

      final date = entry.value['date'] as DateTime;
      final isToday =
          DateFormat('yyyy-MM-dd').format(date) ==
          DateFormat('yyyy-MM-dd').format(DateTime.now());

      return {
        'date': date,
        'day': isToday ? 'Today' : DateFormat('EEEE').format(date),
        'formattedDate': DateFormat('MMM d').format(date),
        'highTemp': '${(entry.value['temp_max'] as double).round()}°C',
        'lowTemp': '${(entry.value['temp_min'] as double).round()}°C',
        'condition': _getWeatherCondition(mostCommonCondition),
        'icon': entry.value['icon'] as String,
      };
    }).toList();

    result.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );
    return result.take(7).toList();
  }

  String _getMostCommonCondition(List<String> conditions) {
    final frequency = <String, int>{};
    for (final condition in conditions) {
      frequency[condition] = (frequency[condition] ?? 0) + 1;
    }

    if (frequency.isEmpty) return 'Clear';

    String mostCommon = 'Clear';
    int maxCount = 0;

    frequency.forEach((key, value) {
      if (value > maxCount) {
        maxCount = value;
        mostCommon = key;
      }
    });

    return mostCommon;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    final isDarkMode = themeProvider.isDarkMode;
    final width = MediaQuery.of(context).size.width;

    final primaryColor = const Color(0xFF22C358);
    final backgroundColor = isDarkMode
        ? Colors.transparent
        : Colors.transparent;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF3F3F3F);
    final secondaryTextColor = isDarkMode
        ? Colors.grey[400]!
        : const Color(0xFF555555);
    final cardColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final cardBorderColor = isDarkMode
        ? Colors.grey[700]!
        : const Color(0xFFE0E0E0);
    final searchBgColor = isDarkMode ? Colors.grey[700]! : Colors.grey.shade50;
    final searchBorderColor = isDarkMode
        ? Colors.grey[600]!
        : Colors.grey.shade200;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: backgroundColor,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.04,
          vertical: width * 0.05,
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.02),
              child: Text(
                'Weather Forecast',
                style: GoogleFonts.inter(
                  fontSize: width * 0.055,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),

            SizedBox(height: width * 0.02),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.02),
              child: Text(
                'Real-time weather updates for agricultural planning',
                style: GoogleFonts.inter(
                  fontSize: width * 0.035,
                  color: secondaryTextColor,
                ),
              ),
            ),

            SizedBox(height: width * 0.04),

            _buildCitySearch(
              width,
              isDarkMode,
              searchBgColor,
              searchBorderColor,
              textColor,
              secondaryTextColor,
              primaryColor,
            ),

            SizedBox(height: width * 0.04),

            if (isLoading) _buildLoadingIndicator(width, primaryColor),

            if (errorMessage.isNotEmpty)
              _buildErrorMessage(width, isDarkMode, errorMessage),

            if (weatherData != null && !isLoading)
              _buildCurrentWeather(
                width,
                isDarkMode,
                cardColor,
                cardBorderColor,
                textColor,
                secondaryTextColor,
                primaryColor,
              ),

            if (!isLoading && forecastData != null)
              _buildWeatherForecast(
                width,
                isDarkMode,
                cardColor,
                cardBorderColor,
                textColor,
                secondaryTextColor,
                primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitySearch(
    double width,
    bool isDarkMode,
    Color bgColor,
    Color borderColor,
    Color textColor,
    Color hintColor,
    Color primaryColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.04,
        vertical: width * 0.03,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(width * 0.03),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(width * 0.03),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.blue.shade900.withOpacity(0.3)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(width * 0.03),
            ),
            child: Icon(
              Icons.location_on,
              color: isDarkMode ? Colors.blue[300] : Colors.blue.shade700,
              size: width * 0.06,
            ),
          ),
          SizedBox(width: width * 0.03),
          Expanded(
            child: TextField(
              controller: cityController,
              decoration: InputDecoration(
                hintText: 'Enter city name',
                hintStyle: GoogleFonts.inter(color: hintColor),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: width * 0.04,
              ),
              onSubmitted: (_) => _fetchWeatherData(),
            ),
          ),
          GestureDetector(
            onTap: _fetchWeatherData,
            child: Container(
              padding: EdgeInsets.all(width * 0.03),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(width * 0.03),
              ),
              child: Icon(
                Icons.search,
                color: Colors.white,
                size: width * 0.06,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(double width, Color primaryColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: width * 0.2),
      child: Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          SizedBox(height: width * 0.04),
          Text(
            'Loading weather data...',
            style: GoogleFonts.inter(
              fontSize: width * 0.04,
              color: const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(
    double width,
    bool isDarkMode,
    String errorMessage,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: width * 0.02),
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.red.shade900.withOpacity(0.2)
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(width * 0.03),
        border: Border.all(
          color: isDarkMode ? Colors.red.shade700 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade400,
            size: width * 0.06,
          ),
          SizedBox(width: width * 0.03),
          Expanded(
            child: Text(
              errorMessage,
              style: GoogleFonts.inter(
                color: Colors.red.shade400,
                fontSize: width * 0.035,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeather(
    double width,
    bool isDarkMode,
    Color cardColor,
    Color cardBorderColor,
    Color textColor,
    Color secondaryTextColor,
    Color primaryColor,
  ) {
    final tempValue = weatherData!['main']['temp'];
    final temp = (tempValue is num ? tempValue : 0).round();
    final condition = weatherData!['weather'][0]['main'] as String;
    final city = weatherData!['name'] as String;
    final country = weatherData!['sys']?['country'] as String? ?? '';
    final icon = weatherData!['weather'][0]['icon'] as String;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: width * 0.02),
      padding: EdgeInsets.all(width * 0.05),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(width * 0.05),
        border: Border.all(color: cardBorderColor),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(width * 0.02),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.blue.shade900.withOpacity(0.3)
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(width * 0.02),
                        ),
                        child: Icon(
                          Icons.location_city,
                          color: isDarkMode
                              ? Colors.blue[300]
                              : Colors.blue.shade700,
                          size: width * 0.04,
                        ),
                      ),
                      SizedBox(width: width * 0.02),
                      Text(
                        'Current Location',
                        style: GoogleFonts.inter(
                          color: secondaryTextColor,
                          fontSize: width * 0.035,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: width * 0.01),
                  Text(
                    country.isNotEmpty ? '$city, $country' : city,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: width * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.all(width * 0.03),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode
                      ? Colors.grey[700]!.withOpacity(0.5)
                      : Colors.grey.shade100,
                  boxShadow: isDarkMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                ),
                child: Image.network(
                  _getWeatherIconUrl(icon),
                  width: width * 0.1,
                  height: width * 0.1,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.wb_sunny,
                      size: width * 0.08,
                      color: isDarkMode ? Colors.amber.shade300 : Colors.amber,
                    );
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: width * 0.05),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(width * 0.03),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.green.shade900.withOpacity(0.2)
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(width * 0.03),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.green.shade800
                        : Colors.green.shade100,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temperature',
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: width * 0.035,
                      ),
                    ),
                    Text(
                      '$temp°C',
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: width * 0.07,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: width * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Condition',
                      style: GoogleFonts.inter(
                        color: secondaryTextColor,
                        fontSize: width * 0.035,
                      ),
                    ),
                    SizedBox(height: width * 0.01),
                    Text(
                      _getWeatherCondition(condition),
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: width * 0.045,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: width * 0.02),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.03,
                        vertical: width * 0.015,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.orange.shade900.withOpacity(0.2)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(width * 0.02),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.orange.shade800
                              : Colors.orange.shade100,
                        ),
                      ),
                      child: Text(
                        'Updated: ${DateFormat('hh:mm a').format(DateTime.now())}',
                        style: GoogleFonts.inter(
                          color: isDarkMode
                              ? Colors.orange[300]
                              : Colors.orange.shade700,
                          fontSize: width * 0.03,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherForecast(
    double width,
    bool isDarkMode,
    Color cardColor,
    Color cardBorderColor,
    Color textColor,
    Color secondaryTextColor,
    Color primaryColor,
  ) {
    final dailyForecast = _getDailyForecast();

    if (dailyForecast.isEmpty) {
      return Container(
        padding: EdgeInsets.all(width * 0.05),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(width * 0.05),
          border: Border.all(color: cardBorderColor),
          boxShadow: isDarkMode
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.cloud_off,
                size: width * 0.1,
                color: secondaryTextColor,
              ),
              SizedBox(height: width * 0.03),
              Text(
                'No forecast data available',
                style: GoogleFonts.inter(
                  color: secondaryTextColor,
                  fontSize: width * 0.04,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(width * 0.03),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.orange.shade900.withOpacity(0.3)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(width * 0.03),
              ),
              child: Icon(
                Icons.calendar_today,
                color: isDarkMode ? Colors.orange[300] : Colors.orange.shade700,
                size: width * 0.06,
              ),
            ),
            SizedBox(width: width * 0.03),
            Text(
              '7-Day Forecast',
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: width * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        SizedBox(height: width * 0.04),

        Column(
          children: dailyForecast.map((dayData) {
            return Padding(
              padding: EdgeInsets.only(bottom: width * 0.04),
              child: _buildWeatherCard(
                width: width,
                isDarkMode: isDarkMode,
                cardColor: cardColor,
                cardBorderColor: cardBorderColor,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                primaryColor: primaryColor,
                day: dayData['day'] as String,
                date: dayData['formattedDate'] as String,
                highTemp: dayData['highTemp'] as String,
                lowTemp: dayData['lowTemp'] as String,
                condition: dayData['condition'] as String,
                iconUrl: _getWeatherIconUrl(dayData['icon'] as String),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWeatherCard({
    required double width,
    required bool isDarkMode,
    required Color cardColor,
    required Color cardBorderColor,
    required Color textColor,
    required Color secondaryTextColor,
    required Color primaryColor,
    required String day,
    required String date,
    required String highTemp,
    required String lowTemp,
    required String condition,
    required String iconUrl,
  }) {
    Color getDayColor(String day) {
      if (day == 'Today') {
        return primaryColor;
      }
      if (day == 'Saturday' || day == 'Sunday') {
        return isDarkMode ? Colors.red.shade300 : Colors.red.shade700;
      }
      return textColor;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(width: 2, color: cardBorderColor),
        borderRadius: BorderRadius.circular(width * 0.04),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: width * 0.15,
            child: Column(
              children: [
                Text(
                  day.substring(0, 3),
                  style: GoogleFonts.inter(
                    color: getDayColor(day),
                    fontSize: width * 0.04,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: width * 0.01),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    color: secondaryTextColor,
                    fontSize: width * 0.035,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: width * 0.04),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.03,
                        vertical: width * 0.015,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.red.shade900.withOpacity(0.2)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(width * 0.02),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.red.shade800
                              : Colors.red.shade100,
                        ),
                      ),
                      child: Text(
                        highTemp,
                        style: GoogleFonts.inter(
                          color: isDarkMode
                              ? Colors.red[300]
                              : Colors.red.shade700,
                          fontSize: width * 0.04,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: width * 0.02),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.03,
                        vertical: width * 0.015,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.blue.shade900.withOpacity(0.2)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(width * 0.02),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.blue.shade800
                              : Colors.blue.shade100,
                        ),
                      ),
                      child: Text(
                        lowTemp,
                        style: GoogleFonts.inter(
                          color: isDarkMode
                              ? Colors.blue[300]
                              : Colors.blue.shade700,
                          fontSize: width * 0.04,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: width * 0.01),
                Text(
                  condition,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: width * 0.038,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: EdgeInsets.all(width * 0.02),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode
                  ? Colors.grey[700]!.withOpacity(0.3)
                  : Colors.grey.shade100,
            ),
            child: Image.network(
              iconUrl,
              width: width * 0.1,
              height: width * 0.1,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  condition == 'Sunny'
                      ? Icons.wb_sunny
                      : condition == 'Cloudy'
                      ? Icons.cloud
                      : condition == 'Rainy'
                      ? Icons.beach_access
                      : condition == 'Stormy'
                      ? Icons.thunderstorm
                      : Icons.wb_cloudy,
                  size: width * 0.07,
                  color: primaryColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cityController.dispose();
    super.dispose();
  }
}
