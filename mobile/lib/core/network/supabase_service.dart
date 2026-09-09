import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';

class SupabaseService {
  final ApiClient apiClient;
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authSubscription;

  // Mock / offline user for development when Supabase credentials are not yet configured
  String? _mockUserEmail;
  String? _mockUserId;

  SupabaseService({required this.apiClient});

  bool get isInitialized => _isInitialized;

  bool get isAuthenticated {
    if (_isInitialized) {
      return Supabase.instance.client.auth.currentSession != null;
    }
    return _mockUserId != null;
  }

  String? get currentUserEmail {
    if (_isInitialized) {
      return Supabase.instance.client.auth.currentUser?.email;
    }
    return _mockUserEmail;
  }

  String? get currentUserId {
    if (_isInitialized) {
      return Supabase.instance.client.auth.currentUser?.id;
    }
    return _mockUserId;
  }

  String? get currentAccessToken {
    if (_isInitialized) {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    }
    return _mockUserId != null ? 'dev-user-$_mockUserId' : null;
  }

  String? get currentDisplayName {
    if (_isInitialized) {
      final user = Supabase.instance.client.auth.currentUser;
      final metaName = user?.userMetadata?['name'] ?? user?.userMetadata?['full_name'];
      if (metaName != null && metaName.toString().trim().isNotEmpty) {
        return metaName.toString().trim();
      }
      final email = user?.email;
      if (email != null && email.contains('@')) {
        final prefix = email.split('@').first;
        if (prefix.isNotEmpty) {
          return prefix[0].toUpperCase() + prefix.substring(1);
        }
      }
    }
    if (_mockUserEmail != null && _mockUserEmail!.contains('@')) {
      final prefix = _mockUserEmail!.split('@').first;
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1);
      }
    }
    return null;
  }

  Future<void> initialize({
    String? url,
    String? anonKey,
  }) async {
    // Only attempt live Supabase init if valid credentials are provided
    if (url != null &&
        url.isNotEmpty &&
        !url.contains('your-project') &&
        anonKey != null &&
        anonKey.isNotEmpty &&
        !anonKey.contains('your-anon-key')) {
      try {
        await Supabase.initialize(
          url: url,
          anonKey: anonKey,
        );
        _isInitialized = true;

        // Listen for session changes and automatically synchronize with ApiClient
        _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          final token = data.session?.accessToken;
          apiClient.setAuthToken(token);
        });

        // Set current token if session already exists
        apiClient.setAuthToken(Supabase.instance.client.auth.currentSession?.accessToken);
        debugPrint('Supabase initialized successfully.');
      } catch (e) {
        debugPrint('Supabase live initialization failed: $e. Falling back to offline mode.');
        _isInitialized = false;
      }
    } else {
      debugPrint('Supabase credentials not configured. Running in offline/dev mode.');
      _isInitialized = false;
    }
  }

  Future<String?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (_isInitialized) {
      try {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        apiClient.setAuthToken(res.session?.accessToken);
        return null; // Success
      } on AuthException catch (e) {
        return e.message;
      } catch (e) {
        return 'Sign in failed: $e';
      }
    } else {
      // Mock sign in for dev
      _mockUserId = email.split('@').first;
      _mockUserEmail = email;
      apiClient.setAuthToken('dev-user-$_mockUserId');
      return null;
    }
  }

  Future<String?> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    if (_isInitialized) {
      try {
        final res = await Supabase.instance.client.auth.signUp(
          email: email.trim(),
          password: password,
        );
        if (res.session != null) {
          apiClient.setAuthToken(res.session!.accessToken);
        }
        return null;
      } on AuthException catch (e) {
        return e.message;
      } catch (e) {
        return 'Sign up failed: $e';
      }
    } else {
      // Mock sign up for dev
      _mockUserId = email.split('@').first;
      _mockUserEmail = email;
      apiClient.setAuthToken('dev-user-$_mockUserId');
      return null;
    }
  }

  Future<String?> signInWithOtp({required String email}) async {
    if (_isInitialized) {
      try {
        await Supabase.instance.client.auth.signInWithOtp(email: email.trim());
        return null;
      } on AuthException catch (e) {
        return e.message;
      } catch (e) {
        return 'Magic link failed: $e';
      }
    } else {
      _mockUserId = email.split('@').first;
      _mockUserEmail = email;
      apiClient.setAuthToken('dev-user-$_mockUserId');
      return null;
    }
  }

  Future<void> signOut() async {
    if (_isInitialized) {
      await Supabase.instance.client.auth.signOut();
    }
    _mockUserId = null;
    _mockUserEmail = null;
    apiClient.setAuthToken(null);
  }

  void dispose() {
    _authSubscription?.cancel();
  }
}
