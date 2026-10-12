/// One bundled Help question. Static text shipped with the app (no network, no backend content): every answer describes only what the screens
/// do today and sends anything about school rules to "your school administration". No phone numbers, deadlines or policies are stated here.
class TeacherFaq {
  final String id;
  final String question;
  final String answer;
  const TeacherFaq(this.id, this.question, this.answer);
}

const List<TeacherFaq> kTeacherFaqs = [
  TeacherFaq(
    'sign_in',
    'I cannot sign in or I forgot my password',
    'On the sign-in screen tap "Forgot password?", enter your email and choose "Send reset link". If your email is registered you receive a link: open it on this phone '
        'and choose a new password, or copy it and paste it on the "Set a new password" screen. If no email arrives, check your spam folder and spelling, then request a new link. '
        'If you still cannot sign in, contact your school administration: they manage your account.',
  ),
  TeacherFaq(
    'attendance',
    'How do I mark attendance?',
    'Attendance is for class teachers: only the class teacher of a class marks its daily attendance, so the entry appears only for you if your school has made you one. '
        'Open Attendance, mark each student for the day and tap Submit; you are shown a summary to check first. You can change a mark and save again, '
        'but only for the last 7 days; older days are read-only. If you should be a class teacher and the entry is missing, ask your school administration.',
  ),
  TeacherFaq(
    'marks',
    'How do I enter marks?',
    'Open Classes, then Assessments & marks. Your school schedules assessments per class; once one covers a class and subject you teach it appears in the list. '
        'Open it, enter the marks (and optional remarks) for each student and choose Review & save. The app tells you how many students have no mark yet and which are below '
        'the pass mark before it saves. If an assessment you expect is missing, ask your school administration.',
  ),
  TeacherFaq(
    'homework',
    'How do I set and grade homework?',
    'Open Classes, then Homework, and create a new one for one of your classes. When you choose "Assign to class" the guardians of the students in that class are notified. '
        'Open a homework and choose "Submissions and grading" to see what has been handed in, then open a submission to give marks and feedback. '
        'Attachments can be PDF, JPG, PNG, WEBP, DOC or DOCX, up to 10 MB each (maximum 5). If you cannot choose a class, you are not assigned to one yet: ask your school administration.',
  ),
  TeacherFaq(
    'leave',
    'How do I apply for leave?',
    'Open More, then My leave, and choose Apply for leave. Pick the type and dates, add a reason and tap Send request. The request goes to your school for a decision, '
        'and you are notified when it is decided; its status shows under My leave. If your balance shows no days, no allowance has been set up for you yet: ask your school administration.',
  ),
  TeacherFaq(
    'messages',
    'How do I message a parent?',
    'Open the Messages tab and choose New message, then choose a student from your classes and write your message. You message guardians inside the app: their phone number '
        'and email are not shown to you. A student with no guardian account cannot be messaged in the app. A closed conversation can be read but nobody can send new messages in it.',
  ),
  TeacherFaq(
    'student_leave',
    'A parent applied for leave for their child. Where do I see it?',
    'Class teachers see these under More, then Student leave requests (and as a notification). Open a request to read it and approve or reject it. '
        'If you are not a class teacher this entry is not shown to you.',
  ),
  TeacherFaq(
    'contact_school',
    'Who do I contact if something is wrong or missing?',
    'For your account, class or subject assignment, a missing assessment or anything about school rules, contact your school administration. '
        'For anything about a child\'s safety, use "Raise a concern" under More or speak to your safeguarding lead; do not wait for a reply in Help.',
  ),
];
