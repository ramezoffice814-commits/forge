import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository_provider.dart';
import '../domain/usecases/delete_account_request_usecase.dart';
import '../domain/usecases/request_password_reset_usecase.dart';
import '../domain/usecases/restore_session_usecase.dart';
import '../domain/usecases/sign_in_usecase.dart';
import '../domain/usecases/sign_out_usecase.dart';
import '../domain/usecases/sign_up_usecase.dart';
import '../domain/usecases/update_password_usecase.dart';

final signInUseCaseProvider = Provider(
  (ref) => SignInUseCase(ref.watch(authRepositoryProvider)),
);
final signUpUseCaseProvider = Provider(
  (ref) => SignUpUseCase(ref.watch(authRepositoryProvider)),
);
final signOutUseCaseProvider = Provider(
  (ref) => SignOutUseCase(ref.watch(authRepositoryProvider)),
);
final restoreSessionUseCaseProvider = Provider(
  (ref) => RestoreSessionUseCase(ref.watch(authRepositoryProvider)),
);
final requestPasswordResetUseCaseProvider = Provider(
  (ref) => RequestPasswordResetUseCase(ref.watch(authRepositoryProvider)),
);
final updatePasswordUseCaseProvider = Provider(
  (ref) => UpdatePasswordUseCase(ref.watch(authRepositoryProvider)),
);
final deleteAccountRequestUseCaseProvider = Provider(
  (ref) => DeleteAccountRequestUseCase(ref.watch(authRepositoryProvider)),
);
