import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';

class AuthModal extends StatefulWidget {
  final SupabaseService supabaseService;
  final VoidCallback onAuthSuccess;

  const AuthModal({
    super.key,
    required this.supabaseService,
    required this.onAuthSuccess,
  });

  static void show(
    BuildContext context, {
    required SupabaseService supabaseService,
    required VoidCallback onAuthSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AuthModal(
          supabaseService: supabaseService,
          onAuthSuccess: onAuthSuccess,
        ),
      ),
    );
  }

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  bool isSignUp = false;
  bool isMagicLink = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;
  String? infoMessage;

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || (!email.contains('@') || !email.contains('.'))) {
      setState(() => errorMessage = 'Please enter a valid email address.');
      return;
    }

    if (!isMagicLink && password.length < 6) {
      setState(() => errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      infoMessage = null;
    });

    String? error;
    if (isMagicLink) {
      error = await widget.supabaseService.signInWithOtp(email: email);
      if (error == null) {
        setState(() {
          isLoading = false;
          infoMessage = 'Check your email for the magic sign-in link!';
        });
        return;
      }
    } else if (isSignUp) {
      error = await widget.supabaseService.signUpWithPassword(
        email: email,
        password: password,
      );
    } else {
      error = await widget.supabaseService.signInWithPassword(
        email: email,
        password: password,
      );
    }

    if (!mounted) return;

    setState(() => isLoading = false);

    if (error != null) {
      setState(() => errorMessage = error);
    } else {
      Navigator.of(context).pop();
      widget.onAuthSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSignUp ? 'Account created successfully!' : 'Signed in successfully!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<ScriptureThemeExtension>() ??
        ScriptureThemeExtension.light;

    return Material(
      color: ext.paper,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ext.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isMagicLink
                      ? 'Magic Link Sign In'
                      : (isSignUp ? 'Create Account' : 'Welcome Back'),
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ext.ink,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: ext.inkSoft),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to sync your notes, bookmarks, and memorization streaks.',
              style: TextStyle(fontSize: 13, color: ext.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 18),

            // Toggle Tabs
            if (!isMagicLink)
              Container(
                decoration: BoxDecoration(
                  color: ext.paperSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ext.line),
                ),
                child: Row(
                  children: [
                    _tabButton('Sign In', !isSignUp, () => setState(() => isSignUp = false), ext),
                    _tabButton('Sign Up', isSignUp, () => setState(() => isSignUp = true), ext),
                  ],
                ),
              ),
            const SizedBox(height: 18),

            // Error / Info Messages
            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),
            if (infoMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: ext.tealSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ext.teal.withOpacity(0.3)),
                ),
                child: Text(
                  infoMessage!,
                  style: TextStyle(color: ext.teal, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),

            // Email Field
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              ext: ext,
            ),
            const SizedBox(height: 12),

            // Password Field (if not magic link)
            if (!isMagicLink) ...[
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: true,
                ext: ext,
              ),
              const SizedBox(height: 18),
            ],

            // Action Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isMagicLink
                            ? 'Send Magic Link'
                            : (isSignUp ? 'Create Account' : 'Sign In'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // Magic Link / Password Toggle
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    isMagicLink = !isMagicLink;
                    errorMessage = null;
                    infoMessage = null;
                  });
                },
                child: Text(
                  isMagicLink ? 'Use email & password instead' : 'Sign in with Magic Link instead',
                  style: TextStyle(fontSize: 12.5, color: ext.teal, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String title, bool isSelected, VoidCallback onTap, ScriptureThemeExtension ext) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? ext.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : ext.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required ScriptureThemeExtension ext,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ext.paperSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, color: ext.ink),
        decoration: InputDecoration(
          icon: Icon(icon, size: 18, color: ext.inkSoft),
          hintText: label,
          hintStyle: TextStyle(color: ext.inkSoft, fontSize: 13.5),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
