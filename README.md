# Eco Cycle

Eco Cycle is a Flutter-powered waste classification and community rewards app. It combines on-device image classification with Supabase-backed user profiles, moderator review workflows, and administrative controls.

## Live Demo

- Web app: https://eco-cycle-live-henna.vercel.app/

## App Download

- Android download: `https://drive.google.com/file/d/1uzWW7nB5sBuEhBOWlzGejaeuJATRPyBY/view?usp=sharing`

  

## Key Features

- **On-Device Image Classification** using TensorFlow Lite model for instant waste categorization
- **Confidence-Based Processing** with automatic approval for high-confidence scans and moderator review for uncertain classifications
- **User Dashboard** displaying points, rank, recent scans, streak, and environmental impact metrics
- **Moderator Dashboard** for reviewing pending disputes and approving/rejecting classifications
- **Admin Dashboard** for managing users, support tickets, and system administration
- **Supabase Integration** with authentication, real-time database, and role-based access control
- **Cross-Platform Support** for Android, iOS, Web, and Desktop
- **Branded Experience** with custom splash screen, launcher icons, and responsive UI
- **Community Rewards System** with leaderboards and achievement tracking
- **Support System** for user assistance and issue reporting

## Project Details

| Aspect | Details |
|--------|---------|
| **IDE** | Visual Studio Code |
| **Language** | Dart |
| **Framework** | Flutter |
| **Platform** | Cross-platform (Android, iOS, Web, macOS) |
| **Backend** | Supabase |
| **ML Model** | TensorFlow Lite |
| **Database** | PostgreSQL (via Supabase) |
| **State Management** | Provider / Riverpod |
| **Screen Resolution** | Responsive (Mobile: 360x640+, Web: 1280x720+) |

## How to Run the Project

### Prerequisites
- **Flutter SDK** (version 3.0 or higher)
- **Dart SDK** (included with Flutter)
- **Android Studio** or **Xcode** for mobile development
- **Supabase Account** for backend services
- **Visual Studio Code** with Flutter extensions

### Setup & Execution Steps

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Shaheerimam/EcoCycle.git
   cd eco_cycle
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a Supabase project
   - Run the SQL scripts in `supabase/` folder to set up database tables
   - Update environment variables with your Supabase URL and anon key

4. **Run the App**
   - For Android: `flutter run`
   - For iOS: `flutter run` (on macOS with Xcode)
   - For Web: `flutter run -d chrome`
   - For Desktop: `flutter run -d macos`

## How to Use

### App Screens

| Screen | Purpose |
|--------|---------|
| **Splash Screen** | Branded app loading experience |
| **Authentication** | User login/signup with Supabase auth |
| **Home/Dashboard** | Main scanning interface and user statistics |
| **Scan** | Camera interface for waste classification |
| **Profile** | User profile with stats and achievements |
| **Moderator Dashboard** | Review pending classifications |
| **Admin Dashboard** | System administration and user management |
| **Settings** | App preferences and support |

### App Controls

| Action | Control |
|--------|---------|
| **Scan Waste** | Camera button on home screen |
| **View Profile** | Profile icon in navigation |
| **Access Dashboard** | Dashboard tab |
| **Submit Support Ticket** | Settings → Support |
| **Logout** | Settings → Logout |

### App Rules

1. **Classification System**
   - High-confidence scans (>80%) are automatically approved
   - Low-confidence scans are sent to moderators for review
   - Users earn points based on correct classifications

2. **Rewards System**
   - Points awarded for each approved scan
   - Streaks bonus for consecutive daily scans
   - Rank progression based on total points

3. **Moderator Workflow**
   - Review pending disputes with image and AI prediction
   - Approve or reject classifications
   - Maintain community accuracy

4. **Admin Functions**
   - Manage user accounts and roles
   - Handle support tickets
   - Monitor system metrics

## Project Structure

```
eco_cycle/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── classifier/                        # ML model integration
│   ├── core/                              # Core utilities and services
│   │   ├── theme/                        # App theming
│   │   └── services/                     # Supabase and API services
│   ├── features/                         # Feature modules
│   │   ├── home/                         # Home screen and scanning
│   │   ├── auth/                         # Authentication
│   │   ├── profile/                      # User profile
│   │   ├── moderator/                    # Moderator dashboard
│   │   └── admin/                        # Admin dashboard
│   └── screens/                          # Additional screens
├── android/                               # Android platform code
├── ios/                                  # iOS platform code
├── web/                                  # Web platform code
├── macos/                                # macOS platform code
├── assets/                               # App assets
│   ├── images/                          # Static images
│   ├── icons/                           # App icons
│   ├── model/                           # TFLite model files
│   └── labels.txt                       # Classification labels
├── supabase/                             # Database setup scripts
│   ├── get_admin_user_profiles.sql      # Admin user queries
│   ├── leaderboard_setup.sql            # Leaderboard tables
│   ├── pending_disputes_setup.sql       # Dispute management
│   └── support_tickets_setup.sql        # Support system
├── pubspec.yaml                         # Flutter dependencies
├── analysis_options.yaml                # Code analysis config
└── test/                                # Unit and widget tests
```

## App Features in Detail

### ML Classification
- **TensorFlow Lite Integration**: On-device model for privacy and speed
- **Real-time Processing**: Instant classification with confidence scores
- **Fallback System**: Moderator review for uncertain predictions

### User System
- **Supabase Auth**: Secure authentication and user management
- **Role-Based Access**: User, Moderator, and Admin roles
- **Profile Management**: Statistics tracking and achievements

### Backend Integration
- **Real-time Database**: Live updates for leaderboards and stats
- **Storage**: Image uploads for dispute reviews
- **Functions**: Server-side logic for complex operations

### UI/UX
- **Responsive Design**: Optimized for mobile and web
- **Material Design**: Consistent Flutter theming
- **Accessibility**: Screen reader support and high contrast

## Technologies Used

- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **Supabase**: Backend-as-a-Service
- **TensorFlow Lite**: On-device machine learning
- **Provider**: State management
- **Camera**: Device camera access
- **Image Picker**: Gallery image selection

## Performance Optimization

- On-device ML inference for offline capability
- Lazy loading of images and data
- Efficient state management with minimal rebuilds
- Optimized database queries with Supabase

## Known Limitations

- Requires camera permissions for scanning
- ML model accuracy depends on training data
- Internet connection needed for Supabase features
- Limited to supported waste categories

## Troubleshooting

| Issue | Solution |
|-------|----------|
| App won't start | Ensure Flutter is installed and configured correctly |
| Camera not working | Grant camera permissions in device settings |
| ML model errors | Verify model files are in assets folder |
| Supabase connection fails | Check internet connection and API keys |
| Build fails | Run `flutter clean` and `flutter pub get` |

## Project Contributors

- **Mohammad Shaheer Imam** - Backend database connection, UI integration with methods, and core app architecture
- **Mohammed Rif Ahsan** - UI development, user interface design, and comprehensive bug testing
- **Zamilur Rahman** - Quality assurance testing, bug reporting, and user experience validation

## Technical Implementation

### App Architecture
- **MVVM Pattern**: Separation of UI, business logic, and data
- **Provider Pattern**: State management across the app
- **Repository Pattern**: Data access abstraction

### Data Flow
- User actions trigger state changes
- State updates notify UI components
- Database operations handled via Supabase client
- ML inference runs locally on device

### Security
- Supabase Row Level Security (RLS)
- Secure API key management
- User authentication required for sensitive operations

## Development Environment

The project is configured for development in VS Code with:
- Flutter SDK
- Dart extensions
- Supabase CLI for local development
- Hot reload for rapid iteration

## Future Enhancement Possibilities

- [ ] Enhanced ML models with more waste categories
- [ ] Social features for community challenges
- [ ] Offline mode with local data sync
- [ ] Advanced analytics and reporting
- [ ] Integration with recycling centers
- [ ] Gamification elements and rewards

## Installation & Resources

**GitHub Repository**: [EcoCycle](https://github.com/Shaheerimam/EcoCycle)

**Resources Required**:
- Flutter SDK
- Supabase account
- Android/iOS development environment
- 200 MB free disk space



---

**Last Updated**: April 2026  
**Version**: 1.0.0




