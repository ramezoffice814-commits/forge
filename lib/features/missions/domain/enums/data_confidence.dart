/// How much [BehavioralHistory] there is to reason from. Low confidence
/// (e.g. a brand-new user) makes the difficulty engine and scorer favor
/// conservative, easy defaults rather than trusting thin history.
enum DataConfidence { low, medium, high }

enum FitnessSelfAssessment { low, moderate, high }
