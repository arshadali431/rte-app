import 'package:flutter/material.dart';
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
import '../screens/office/office_login_screen.dart';
import '../screens/rte/rte_status_screen.dart';
import '../screens/maintenance_screen.dart';
import '../models/token_model.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/role',
        name: 'role',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const RoleSelectionScreen(),
        ),
      ),
      // Parent Path
      GoRoute(
        path: '/parent/token-entry',
        name: 'token-entry',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const TokenEntryScreen(),
        ),
      ),
      GoRoute(
        path: '/parent/dashboard',
        name: 'parent-dashboard',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const ParentDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/parent/child-profile',
        name: 'child-profile',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const ChildProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/parent/documents',
        name: 'parent-documents',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const DocumentUploadScreen(),
        ),
      ),
      GoRoute(
        path: '/parent/status',
        name: 'parent-status',
        pageBuilder: (context, state) {
          final tokenId = state.extra as String;
          return _buildPage(
            state: state,
            child: ApplicationStatusScreen(tokenId: tokenId),
          );
        },
      ),
      // Office Path
      GoRoute(
        path: '/office/login',
        name: 'office-login',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const OfficeLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/office/dashboard',
        name: 'office-dashboard',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const OfficeDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/office/new-token',
        name: 'new-token',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const NewTokenScreen(),
        ),
      ),
      GoRoute(
        path: '/office/scan',
        name: 'office-scan',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const ScanQrScreen(),
        ),
      ),
      GoRoute(
        path: '/office/generated-token',
        name: 'generated-token',
        pageBuilder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          return _buildPage(
            state: state,
            child: GeneratedTokenScreen(tokenData: data),
          );
        },
      ),
      GoRoute(
        path: '/office/token-detail',
        name: 'token-detail',
        pageBuilder: (context, state) {
          final token = state.extra as TokenModel;
          return _buildPage(
            state: state,
            child: TokenDetailScreen(token: token),
          );
        },
      ),
      GoRoute(
        path: '/office/search',
        name: 'office-search',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const SearchApplicationScreen(),
        ),
      ),
      GoRoute(
        path: '/rte/status-checker',
        name: 'rte-status-checker',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const RteStatusScreen(),
        ),
      ),
      // Maintenance Path
      GoRoute(
        path: '/maintenance/central',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const MaintenanceScreen(
            allowBack: false, // LOCKED
            message: 'The app is currently under maintenance.\nPlease check back later.',
          ),
        ),
      ),
      GoRoute(
        path: '/maintenance/office',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const MaintenanceScreen(
            allowBack: true, // CAN GO BACK
            message: 'Office access is temporarily unavailable.\nPlease try again later.',
          ),
        ),
      ),
      GoRoute(
        path: '/maintenance/parent',
        pageBuilder: (context, state) => _buildPage(
          state: state,
          child: const MaintenanceScreen(
            allowBack: true, // CAN GO BACK
            message: 'Parent portal is temporarily unavailable.\nPlease try again later.',
          ),
        ),
      ),
    ],
  );

  static CustomTransitionPage _buildPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        );
      },
    );
  }
}
