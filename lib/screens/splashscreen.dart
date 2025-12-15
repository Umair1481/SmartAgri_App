import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: Container(
          color: const Color(0xF8F6E7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  color: const Color(0xF8F6E7),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main content container
                        Container(
                          margin: const EdgeInsets.only(
                            top: 132,
                            bottom: 32,
                            left: 25,
                            right: 25,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Main image
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: size.height * 0.45,
                                    width: double.infinity,
                                    child: Image.asset(
                                      "assets/images/splash_main.png",
                                      fit: BoxFit.fill,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              height: size.height * 0.45,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.image,
                                                size: 50,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ],
                              ),

                              //  FIX: Title moved down properly
                              Positioned(
                                bottom: -25, // pushes text lower
                                left: 10,
                                right: 10,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    "Smart Agriculture System",
                                    style: const TextStyle(
                                      color: Color(0xFF000000),
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    maxLines: 2,
                                    overflow: TextOverflow.visible,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bottom icon
                        Container(
                          margin: const EdgeInsets.only(bottom: 158),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 90),
                                child: SizedBox(
                                  width: 66,
                                  height: 52,
                                  child: Image.asset(
                                    "assets/images/splash_icon.png",
                                    fit: BoxFit.fill,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 66,
                                        height: 52,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.agriculture,
                                          size: 30,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
