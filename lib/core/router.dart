import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/parent/parent_dashboard_screen.dart';
import '../screens/parent/token_entry_screen.dart';
import '../screens/parent/child_profile_screen.dart';
import '../screens/parent/document_upload_screen.dart';
import '../screens/parent/application_status_screen.dart';
import '../screens/office/office_dashboard_screen.dart';
import '../screens/office/new_token_screen.dart';
import '../screens/office/scan_qr_screen.dart';
import '../screens/office/search_application_screen.dart';
import '../screens/office/generated_token_screen.dart';
import '../screens/office/token_detail_screen.dart';
import '../models/token_model.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final parentRoutesRequiringToken = [
        '/parent/dashboard',
        '/parent/child-profile',
        '/parent/documents',
        '/parent/status',
      ];

      if (parentRoutesRequiringToken.contains(state.matchedLocation)) {
        final tokenId = state.extra as String?;
        if (tokenId == null || tokenId.isEmpty) {
          return '/role';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/role',
        name: 'role',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      // Parent Path
      GoRoute(
        path: '/parent/token-entry',
        name: 'token-entry',
        builder: (context, state) => const TokenEntryScreen(),
      ),
      GoRoute(
        path: '/parent/dashboard',
        name: 'parent-dashboard',
        builder: (context, state) => const ParentDashboardScreen(),
      ),
      GoRoute(
        path: '/parent/child-profile',
        name: 'child-profile',
        builder: (context, state) => const ChildProfileScreen(),
      ),
      GoRoute(
        path: '/parent/documents',
        name: 'parent-documents',
        builder: (context, state) => const DocumentUploadScreen(),
      ),
      GoRoute(
        path: '/parent/status',
        name: 'parent-status',
        builder: (context, state) => const ApplicationStatusScreen(),
      ),
      // Office Path (Accessible directly)
      GoRoute(
        path: '/office/dashboard',
        name: 'office-dashboard',
        builder: (context, state) => const OfficeDashboardScreen(),
      ),
      GoRoute(
        path: '/office/new-token',
        name: 'new-token',
        builder: (context, state) => const NewTokenScreen(),
      ),
      GoRoute(
        path: '/office/scan',
        name: 'office-scan',
        builder: (context, state) => const ScanQrScreen(),
      ),
      GoRoute(
        path: '/office/generated-token',
        name: 'generated-token',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return GeneratedTokenScreen(tokenData: data);
        },
      ),
      GoRoute(
        path: '/office/token-detail',
        name: 'token-detail',
        builder: (context, state) {
          final token = state.extra as TokenModel;
          return TokenDetailScreen(token: token);
        },
      ),
      GoRoute(
        path: '/office/search',
        name: 'office-search',
        builder: (context, state) => const SearchApplicationScreen(),
      ),
    ],
  );
}
