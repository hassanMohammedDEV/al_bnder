String get _baseSupabaseUrl => const String.fromEnvironment(
  'SUPABASE_URL',
  // defaultValue: 'https://al-bndr-proxy-5.vercel.app/api',
  defaultValue: 'https://xlcmbxvqdfwlfotyvqas.supabase.co',
);
String get supabaseUrl => '$_baseSupabaseUrl/';
String get supabaseRestUrl => '$_baseSupabaseUrl/rest/v1/';
String get supabaseAnonKey => const String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhsY21ieHZxZGZ3bGZvdHl2cWFzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyNjc0NDYsImV4cCI6MjA5Nzg0MzQ0Nn0.IRkGc1LjeR0pJk4P0-l15deaDkiVQSBd1HhkPDIvS78',
);
