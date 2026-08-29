/// Carries the user's answers across the 3-step onboarding wizard.
/// Passed forward (and mutated) as the user moves Next/Back between steps,
/// then sent as-is to the completeProfile API on the final step.
class OnboardingData {
  String firstName;
  String lastName;
  String email;

  String? occupation;
  String? tradingStyle;

  String? tradingExperience;

  bool confirmAccurate;
  bool agreeTerms;

  OnboardingData({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.occupation,
    this.tradingStyle,
    this.tradingExperience,
    this.confirmAccurate = false,
    this.agreeTerms = false,
  });

  Map<String, dynamic> toCompleteProfilePayload() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'occupation': occupation,
        'tradingStyle': tradingStyle,
        'tradingExperience': tradingExperience,
      };
}