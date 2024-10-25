import 'package:flutter/material.dart';

// Light theme configuration
ThemeData lightMode = ThemeData(
  // Enable Material 3 design system
  useMaterial3: true,

  // Set light mode brightness
  brightness: Brightness.light,

  // Define color scheme for light mode
  colorScheme: const ColorScheme.light(
    surface: Color.fromARGB(255, 245, 243, 236),     // Background surface color
    onPrimary: Color.fromARGB(255, 0, 0, 0),         // Text color on primary background
    primary: Color.fromARGB(175, 207, 202, 199),     // Primary color for main elements
    secondary: Color.fromARGB(166, 178, 212, 178),   // Accent color for interactive elements
    onSecondary: Color.fromARGB(255, 0, 0, 0),       // Text color on secondary background
    tertiary: Color.fromARGB(255, 156, 175, 136),    // Additional accent color
    onTertiary: Color.fromARGB(255, 255, 255, 255),  // Text color on tertiary background
  ),

  // Configure platform-specific page transitions
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),      // Android zoom transition
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),     // iOS slide transition
      TargetPlatform.windows: OpenUpwardsPageTransitionsBuilder(), // Windows upward transition
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),    // macOS slide transition
      TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),  // Linux upward transition
    },
  ),

  // Configure card appearance
  cardTheme: CardTheme(
    elevation: 4,                                      // Card shadow depth
    shadowColor: Colors.black.withOpacity(0.2),       // Subtle shadow color
    shape: RoundedRectangleBorder(                    // Rounded corners for cards
      borderRadius: BorderRadius.circular(12),
    ),
  ),

  // Configure input field appearance
  inputDecorationTheme: InputDecorationTheme(
    filled: true,                                     // Enable background fill
    fillColor: const Color.fromARGB(255, 245, 243, 236).withOpacity(0.5),  // Light background
    border: OutlineInputBorder(                       // Default border style
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color.fromARGB(175, 207, 202, 199)),
    ),
    enabledBorder: OutlineInputBorder(                // Border when field is enabled
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color.fromARGB(175, 207, 202, 199)),
    ),
    focusedBorder: OutlineInputBorder(                // Border when field is focused
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color.fromARGB(166, 178, 212, 178), width: 2),
    ),
  ),

  // Configure elevated button appearance
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      animationDuration: const Duration(milliseconds: 200),  // Button press animation duration
      padding: WidgetStateProperty.all(                      // Consistent button padding
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      shape: WidgetStateProperty.all(                        // Rounded button corners
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  ),
);

// Dark theme configuration
ThemeData darkMode = ThemeData(
  // Enable Material 3 design system
  useMaterial3: true,

  // Set dark mode brightness
  brightness: Brightness.dark,

  // Define color scheme for dark mode
  colorScheme: const ColorScheme.dark(
    surface: Color.fromARGB(255, 50, 50, 50),        // Dark background surface color
    onPrimary: Color.fromARGB(255, 255, 255, 255),   // Text color on primary background
    primary: Color.fromARGB(255, 76, 76, 76),        // Primary color for main elements
    secondary: Color.fromARGB(255, 125, 26, 255),    // Accent color for interactive elements
    onSecondary: Color.fromARGB(255, 255, 255, 255), // Text color on secondary background
    tertiary: Color.fromARGB(255, 90, 24, 154),      // Additional accent color
    onTertiary: Color.fromARGB(255, 255, 255, 255),  // Text color on tertiary background
  ),

  // Configure platform-specific page transitions
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),      // Android zoom transition
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),     // iOS slide transition
      TargetPlatform.windows: OpenUpwardsPageTransitionsBuilder(), // Windows upward transition
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),    // macOS slide transition
      TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),  // Linux upward transition
    },
  ),

  // Configure card appearance for dark mode
  cardTheme: CardTheme(
    elevation: 4,                                      // Card shadow depth
    shadowColor: Colors.black.withOpacity(0.4),       // Stronger shadow for dark mode
    shape: RoundedRectangleBorder(                    // Rounded corners for cards
      borderRadius: BorderRadius.circular(12),
    ),
  ),

  // Configure input field appearance for dark mode
  inputDecorationTheme: InputDecorationTheme(
    filled: true,                                     // Enable background fill
    fillColor: const Color.fromARGB(255, 76, 76, 76).withOpacity(0.5),  // Dark background
    border: OutlineInputBorder(                       // Default border style
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color.fromARGB(255, 90, 90, 90)),
    ),
    enabledBorder: OutlineInputBorder(                // Border when field is enabled
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color.fromARGB(255, 90, 90, 90)),
    ),
    focusedBorder: OutlineInputBorder(                // Border when field is focused
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color.fromARGB(255, 125, 26, 255), width: 2),
    ),
  ),

  // Configure elevated button appearance for dark mode
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      animationDuration: const Duration(milliseconds: 200),  // Button press animation duration
      padding: WidgetStateProperty.all(                      // Consistent button padding
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      shape: WidgetStateProperty.all(                        // Rounded button corners
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  ),
);