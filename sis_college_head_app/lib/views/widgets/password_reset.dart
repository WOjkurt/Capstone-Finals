import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../injection.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Emails a password reset link. The message is the same whether or not the account exists,
/// so this cannot be used to find out who has one.
Future<void> sendPasswordResetLink(BuildContext context, String email) async {
  final messenger = ScaffoldMessenger.of(context);
  void show(String text, {bool error = false}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), backgroundColor: error ? AppColors.error : AppColors.success));

  final address = email.trim();
  if (address.isEmpty) {
    show('Type your school email first, then click Forgot password.', error: true);
    return;
  }
  try {
    await getIt<AuthService>().sendPasswordReset(address);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'invalid-email') {
      show('That email address does not look right. Check it and try again.', error: true);
      return;
    }
    if (e.code != 'user-not-found') {
      show('Could not send the email. Check your connection and try again.', error: true);
      return;
    }
  } catch (_) {
    show('Could not send the email. Check your connection and try again.', error: true);
    return;
  }
  show('If $address has an account, a password link is on its way. Check your inbox and spam folder.');
}

/// For someone already signed in: asks first, then emails a link to set a new password.
Future<void> confirmChangePassword(BuildContext context, String email) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Change password?'),
      content: Text('We will email a link to $email. Open it to set a new password. Your current password keeps working until then.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('confirm_change_password'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Send link'),
        ),
      ],
    ),
  );
  if (yes == true && context.mounted) await sendPasswordResetLink(context, email);
}
