import { Redirect } from 'expo-router';

// Пока авторизации нет, всегда начинаем с экрана входа.
// Позже здесь будет проверка: есть сессия → вкладки, нет → вход.
export default function Index() {
  return <Redirect href="/sign-in" />;
}
