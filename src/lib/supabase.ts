import { createClient } from '@supabase/supabase-js';

// В приложение попадает только публичный anon-ключ: он безопасен, потому что
// все данные защищены RLS на сервере. service_role-ключ здесь быть НЕ должен никогда.
const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Нет EXPO_PUBLIC_SUPABASE_URL или EXPO_PUBLIC_SUPABASE_ANON_KEY. Скопируй .env.example в .env и заполни.',
  );
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    // Сохранение сессии между запусками подключим на шаге авторизации.
    persistSession: false,
    autoRefreshToken: true,
    detectSessionInUrl: false,
  },
});
