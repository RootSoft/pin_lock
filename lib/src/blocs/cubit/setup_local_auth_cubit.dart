import 'package:bloc/bloc.dart';
import 'package:pin_lock/src/blocs/cubit/setup_stage.dart';
import 'package:pin_lock/src/entities/authenticator.dart';
import 'package:pin_lock/src/entities/value_objects.dart';

class SetuplocalauthCubit extends Cubit<SetupStage> {
  final Authenticator authenticator;
  SetuplocalauthCubit(this.authenticator) : super(const Base(isLoading: true));

  Future<void> checkInitialState() async {
    final lastState = state;
    if (lastState is Base) {
      final isPinAuthEnabled = await authenticator.isPinAuthenticationEnabled();
      emit(lastState.copyWith(isPinAuthEnabled: isPinAuthEnabled, isLoading: false));

      final biometrics = await authenticator.getBiometricAuthenticationAvailability();
      biometrics.when(
        available: (isEnabled) {
          emit(lastState.copyWith(
            isPinAuthEnabled: isPinAuthEnabled,
            isBiometricAuthAvailable: true,
            isBiometricAuthEnabled: isEnabled,
            isLoading: false,
          ));
        },
        unavailable: (_) {
          emit(lastState.copyWith(
            isPinAuthEnabled: isPinAuthEnabled,
            isBiometricAuthEnabled: false,
            isBiometricAuthAvailable: false,
            isLoading: false,
          ));
        },
      );
    } else {
      emit(const Base(isLoading: true));
      checkInitialState();
    }
  }

  Future<void> startEnablingPincode() async {
    emit(Enabling(pinLength: authenticator.pinLength));
  }

  void pinEntered(String pin) {
    final lastState = state;
    if (lastState is Enabling) {
      emit(lastState.copyWith(pin: pin));
    }
  }

  void pinConfirmationEntered(String confirmation) {
    final lastState = state;
    if (lastState is Enabling) {
      emit(lastState.copyWith(confirmationPin: confirmation));
    }
  }

  Future<void> savePin() async {
    final lastState = state;
    if (lastState is Enabling) {
      final response = await authenticator.enablePinAuthentication(
        pin: Pin(lastState.pin ?? ''),
        confirmationPin: Pin(lastState.confirmationPin ?? ''),
      );
      response.fold(
        (l) => emit(lastState.copyWith(error: l)),
        (r) {
          emit(const Base(isLoading: true));
          checkInitialState();
        },
      );
    }
  }

  void startDisablingPincode() {
    emit(Disabling(pinLength: authenticator.pinLength));
  }

  void enterPinToDisable(String pin) {
    final lastState = state;
    if (lastState is Disabling) {
      emit(lastState.copyWith(pin: pin));
    }
  }

  Future<void> disablePinAuthentication() async {
    final lastState = state;
    if (lastState is Disabling) {
      final result = await authenticator.disableAuthenticationWithPin(pin: Pin(lastState.pin));
      result.fold(
        (l) => emit(lastState.copyWith(pin: '', error: l)),
        (r) => checkInitialState(),
      );
    }
  }

  void startChangingPincode() {
    emit(ChangingPasscode(pinLength: authenticator.pinLength));
  }

  void enterPinToChange(String pin) {
    final lastState = state;
    if (lastState is ChangingPasscode) {
      emit(lastState.copyWith(currentPin: pin));
    }
  }

  void enterNewPin(String pin) {
    final lastState = state;
    if (lastState is ChangingPasscode) {
      emit(lastState.copyWith(newPin: pin));
    }
  }

  void enterConfirmationPin(String pin) {
    final lastState = state;
    if (lastState is ChangingPasscode) {
      emit(lastState.copyWith(confirmationPin: pin));
    }
  }

  Future<void> changePin() async {
    final lastState = state;
    if (lastState is ChangingPasscode) {
      final result = await authenticator.changePinCode(
        oldPin: Pin(lastState.currentPin),
        newPin: Pin(lastState.newPin),
        newPinConfirmation: Pin(lastState.confirmationPin),
      );
      result.fold(
        (l) {
          l.maybeWhen(
            tooManyAttempts: () => emit(lastState.copyWith(currentPin: '', error: l)),
            wrongPin: () => emit(lastState.copyWith(currentPin: '', error: l)),
            pinNotMatching: () => emit(lastState.copyWith(
              newPin: '',
              confirmationPin: '',
              error: l,
            )),
            orElse: () => emit(lastState.copyWith(error: l)),
          );
        },
        (r) => checkInitialState(),
      );
    }
  }
}
