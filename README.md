# Eco Cycle

Eco Cycle is a Flutter-powered waste classification and community rewards app. It combines on-device image classification with Supabase-backed user profiles, moderator review workflows, and administrative controls.

## Live Demo

- Web app: https://eco-cycle-live-henna.vercel.app/

## App Download

- Android / iOS download: `https://your-download-link.example.com`

  _(Replace this link with your published app store or APK URL.)_

## Key Features

- Image-based waste classification using a local ML model
- Real-time confidence scoring with high-confidence scans confirmed immediately
- Low-confidence scans routed to moderator review as pending disputes
- User dashboard showing points, rank, recent scans, streak, and impact metrics
- Moderator dashboard for reviewing and approving or rejecting pending classifications
- Admin dashboard for managing users, support tickets, and system oversight
- Branded splash screen, launcher icon, and web startup experience
- Supabase authentication, data storage, and role-aware access control

## Project Structure

- `lib/main.dart` — app entry point and theme initialization
- `lib/features/home/home_screen.dart` — core waste scanning and dashboard experience
- `lib/features/moderator/moderator_dashboard_view.dart` — moderator review UI
- `lib/features/admin/admin_dashboard_view.dart` — admin user and ticket management
- `lib/core/theme` — shared theme and styling
- `supabase/` — SQL helper scripts for backend tables and RPC functions

## Technologies

- Flutter
- Supabase
- TFLite / on-device image classification
- Web, Android, iOS, macOS support

## Getting Started

1. Clone the repository
   ```bash
   git clone https://github.com/<your-org>/eco_cycle.git
   cd eco_cycle
   ```
2. Install dependencies
   ```bash
   flutter pub get
   ```
3. Run the app
   ```bash
   flutter run
   ```

## Notes

- Update `lib/main.dart` with your Supabase project URL and anon key
- Ensure `pubspec.yaml` includes the asset declarations for model and image files
- Replace the app download placeholder with your actual published link

## License

This project is provided as-is. Update the license information as needed for your repository.
