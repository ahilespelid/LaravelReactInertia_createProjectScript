#!/bin/bash

# Название проекта
PROJECT_NAME="betabank.ru"
PROJECT_DIR="/var/www/"$PROJECT_NAME

echo $PROJECT_DIR;

# Создаем основную директорию проекта
mkdir -p /var/www; cd /var/www;
composer create-project laravel/laravel $PROJECT_NAME
cd $PROJECT_DIR

composer require laravel/breeze;
composer require inertiajs/inertia-laravel;
php artisan breeze:install react;
rm -f vite.config.js;

# Создаем структуру директорий
mkdir -p app/Http/Controllers app/Http/Middleware app/Models database/migrations resources/css resources/js/src resources/js/src/pages/Auth resources/js/src/layouts resources/views routes bootstrap

# Создаем и заполняем файлы
# 1. app/Models/User.php
cat << 'EOF' > app/Models/User.php
<?php
namespace App\Models;

use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

class User extends Authenticatable implements MustVerifyEmail
{
    use Notifiable;

    protected $fillable = ['login', 'email', 'wallet', 'password', 'two_factor_code', 'exchanger'];
    protected $hidden = ['password', 'remember_token'];
    protected $casts = [
        'email_verified_at'     => 'datetime', 
        'two_factor_expires_at' => 'datetime', 
        'deleted_at'            => 'datetime', 
        'updated_at'            => 'datetime',
        'created_at'            => 'datetime'
    ];
}
EOF

# 2. app/Http/Controllers/UserController.php
cat << 'EOF' > app/Http/Controllers/UserController.php
<?php
namespace App\Http\Controllers;

use Inertia\Inertia;

class UserController extends Controller
{
    public function index()
    {
        return Inertia::render('Dashboard');
    }
}
EOF

# 3. app/Http/Middleware/HandleInertiaRequests.php
cat << 'EOF' > app/Http/Middleware/HandleInertiaRequests.php
<?php
namespace App\Http\Middleware;

use Illuminate\Http\Request;
use Inertia\Middleware;

class HandleInertiaRequests extends Middleware
{
    protected $rootView = 'app';

    public function share(Request $request): array
    {
        return array_merge(parent::share($request), [
            'auth' => [
                'user' => $request->user(),
            ],
        ]);
    }
}
EOF

cat << 'EOF' > app/Http/Middleware/Login.php
<?php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class Login
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response {
        return (auth()->check()) ? $next($request) : redirect('login');
    }
}
EOF

# 4. database/migrations/2014_10_12_000000_create_users_table.php
cat << 'EOF' > database/migrations/2014_10_12_000000_create_users_table.php
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('users');
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->float('wallet')->nullable();
            $table->string('email')->unique();
            $table->string('login')->unique();
            $table->string('password');
            $table->boolean('exchanger')->nullable();
            $table->string('two_factor_code')->nullable();
            $table->timestamp('two_factor_expires_at')->nullable();
            $table->timestamp('email_verified_at')->nullable();
            $table->rememberToken();
            $table->timestamp('deleted_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }
};
EOF

# 5. routes/web.php
cat << 'EOF' > routes/web.php
<?php
use App\Http\Controllers\UserController;
use Illuminate\Foundation\Auth\EmailVerificationRequest;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return inertia('Home');
});

Route::get('/login', function () {
    return inertia('Auth/Login');
});

Route::middleware('login')->group(function () {
    Route::get('/user', [UserController::class, 'index'])->middleware('verified')->name('user');

    Route::get('/email/verify', function () {
        return inertia('Auth/VerifyEmail');
    })->name('verification.notice');

    Route::get('/email/verify/{id}/{hash}', function (EmailVerificationRequest $request) {
        $request->fulfill();
        return redirect()->route('user');
    })->middleware('signed')->name('verification.verify');

    Route::post('/email/verification', function (Request $request) {
        $request->user()->sendEmailVerificationNotification();
        return back()->with('message', 'Verification link sent!');
    })->middleware('throttle:6,1')->name('verification.send');
});
EOF

# 6. resources/views/app.blade.php
cat << 'EOF' > resources/views/app.blade.php
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title inertia>{{ config('app.name', 'Laravel') }}</title>
    @viteReactRefresh
    @vite(['resources/js/app.tsx', 'resources/css/app.css'])
    @inertiaHead
</head>
<body>
    @inertia
</body>
</html>
EOF

# 7. resources/js/app.tsx
cat << 'EOF' > resources/js/app.tsx
import './bootstrap';
import '../css/app.css';
import React from 'react';
import { createRoot } from 'react-dom/client';
import { createInertiaApp } from '@inertiajs/react';
import { resolvePageComponent } from 'laravel-vite-plugin/inertia-helpers';

createInertiaApp({
  title: (title) => `${title} - My App`,
  resolve: (name) =>
    resolvePageComponent(
      `./src/pages/${name}.tsx`,
      import.meta.glob("./src/pages/**/*.tsx")
    ),
  setup({ el, App, props }) {
    const root = createRoot(el);
    root.render(<App {...props} />);
  },
});
EOF

# 8. resources/js/bootstrap.ts
cat << 'EOF' > resources/js/bootstrap.ts
import axios, { AxiosInstance } from 'axios';

window.axios = axios;
window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
EOF

# 9. resources/js/types.ts
cat << 'EOF' > resources/js/types.ts
export interface User {
    id: number;
    name: string;
    email: string;
    email_verified_at: string | null;
}

export interface PageProps {
    auth: {
        user: User | null;
    };
    errors?: Record<string, string>;
}
EOF

# 10. resources/js/src/layouts/AuthenticatedLayout.tsx
cat << 'EOF' > resources/js/src/layouts/AuthenticatedLayout.tsx
import React, { ReactNode } from 'react';
import { User } from '@/types';

interface Props {
    user: User;
    header?: ReactNode;
    children: ReactNode;
}

export default function AuthenticatedLayout({ user, header, children }: Props) {
    return (
        <div className="min-h-screen bg-gray-100">
            <nav className="bg-white border-b border-gray-100">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="flex justify-between h-16">
                        <div className="flex items-center">
                            <span>{user?.name}</span>
                        </div>
                    </div>
                </div>
            </nav>
            {header && (
                <header className="bg-white shadow">
                    <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">{header}</div>
                </header>
            )}
            <main>{children}</main>
        </div>
    );
}
EOF


# 13. resources/css/app.css
cat << 'EOF' > resources/css/app.css
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

# 14. .env
cat << 'EOF' > .env
APP_NAME=Betabank
APP_ENV=local
APP_KEY=base64:W/IYP0aPbzgd6D2y4eJ+KS+/WBUbYPARiKstX7oElFw=
APP_DEBUG=true
APP_TIMEZONE=Europe/Moscow
APP_HOST=dev.betabank.ru
APP_URL=http://${APP_HOST}

APP_LOCALE=ru
APP_FALLBACK_LOCALE=ru
APP_FAKER_LOCALE=ru_RU

APP_MAINTENANCE_DRIVER=file
APP_MAINTENANCE_STORE=database

PHP_CLI_SERVER_WORKERS=4

BCRYPT_ROUNDS=12

LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=betabank
DB_USERNAME=admin
DB_PASSWORD=dzFS{3$x0

SESSION_DRIVER=database
SESSION_LIFETIME=10080
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local
QUEUE_CONNECTION=database

CACHE_STORE=database
# CACHE_PREFIX=

MEMCACHED_HOST=127.0.0.1

REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=465
MAIL_USERNAME=betabanksite@gmail.com
MAIL_PASSWORD=vJRZ9z61oxwwnJiTpCp9
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=betabank.ru@gmail.com
MAIL_FROM_NAME="${APP_NAME}"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

VITE_APP_NAME="${APP_NAME}"
EOF

# 15. composer.json

# 16. package.json
cat << 'EOF' > package.json
{
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "type-check": "tsc --noEmit",
    "postinstall": "vite build"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@inertiajs/react": "^1.0.0",
    "@types/react": "^18.2.55",
    "@types/react-dom": "^18.2.19",
    "@vitejs/plugin-react": "^4.2.1",
    "autoprefixer": "^10.4.16",
    "axios": "^1.6.5",
    "laravel-vite-plugin": "^1.0.0",
    "postcss": "^8.4.35",
    "@tailwindcss/forms": "^0.5.3",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.3.3",
    "vite": "^5.1.4",
    "vite-tsconfig-paths": "^4.2.2"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.1"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# 17. tsconfig.json
cat << 'EOF' > tsconfig.json
{
  "compilerOptions": {
    "types": ["vite/client", "node"],
    "baseUrl": ".",
    "paths": {
      "@/*": ["resources/js/*"]
    },
    "target": "ES6",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": false, // set to true if you need
    "noEmit": true,
    "jsx": "react-jsx"
  },
  "include": ["resources/js/**/*"],
  "files.associations": {
    "*.tsx": "typescriptreact",
    "*.ts": "typescript"
  }
}
EOF

# 18. vite.config.ts
cat << 'EOF' > vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import laravel from "laravel-vite-plugin";
import path from "path";

export default defineConfig({
  plugins: [
    laravel({
      input: ["resources/js/app.tsx", "resources/css/app.css"],
      refresh: true,
    }),
    react(),
  ],
  build: {
    minify: false
  },
  resolve: {
    extensions: [".js", ".ts", ".jsx", ".tsx"], 
    alias: {
      "@": path.resolve(__dirname, 'resources/js/src'),
    },
  },
});
EOF

# 19. tailwind.config.js
cat << 'EOF' > tailwind.config.ts
import defaultTheme from "tailwindcss/defaultTheme";
import forms from "@tailwindcss/forms";

/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./vendor/laravel/framework/src/Illuminate/Pagination/resources/views/*.blade.php",
    "./storage/framework/views/*.php",
    "./resources/views/**/*.blade.php",
    "./resources/js/**/*.jsx",
    "./resources/js/**/*.tsx",
  ],

  theme: {
    extend: {
      fontFamily: {
        sans: ["Figtree", ...defaultTheme.fontFamily.sans],
      },
    },
  },

  plugins: [forms],
};
EOF

# 20. vite.config.js
rm -f vite.config.js 
cat << 'EOF' > vite.config
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [
        laravel({
            input: 'resources/js/app.js',
            refresh: true,
        }),
        react(),
    ],
});
EOF

# 21. resources/js/src/pages/auth/Login.tsx
cat << 'EOF' > resources/js/src/pages/Auth/Login.tsx
import React from 'react';
import { Head } from '@inertiajs/react';

export default function Login() {

    return (
      <>
        <Head title="Авторизация" />
        <div className="max-w-7xl mx-auto sm:px-6 lg:px-8 py-12">
          <div className="bg-white overflow-hidden shadow-sm sm:rounded-lg p-6">
            <form class="max-w-sm mx-auto">
              <div class="mb-5">
                <label
                  for="email"
                  class="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
                >
                  Your email
                </label>
                <input
                  type="email"
                  id="email"
                  class="bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"
                  placeholder="name@flowbite.com"
                  required
                />
              </div>
              <div class="mb-5">
                <label
                  for="password"
                  class="block mb-2 text-sm font-medium text-gray-900 dark:text-white"
                >
                  Your password
                </label>
                <input
                  type="password"
                  id="password"
                  class="bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500 focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500"
                  required
                />
              </div>
              <div class="flex items-start mb-5">
                <div class="flex items-center h-5">
                  <input
                    id="remember"
                    type="checkbox"
                    value=""
                    class="w-4 h-4 border border-gray-300 rounded-sm bg-gray-50 focus:ring-3 focus:ring-blue-300 dark:bg-gray-700 dark:border-gray-600 dark:focus:ring-blue-600 dark:ring-offset-gray-800 dark:focus:ring-offset-gray-800"
                    required
                  />
                </div>
                <label
                  for="remember"
                  class="ms-2 text-sm font-medium text-gray-900 dark:text-gray-300"
                >
                  Remember me
                </label>
              </div>
              <button
                type="submit"
                class="text-white bg-blue-700 hover:bg-blue-800 focus:ring-4 focus:outline-none focus:ring-blue-300 font-medium rounded-lg text-sm w-full sm:w-auto px-5 py-2.5 text-center dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800"
              >
                Submit
              </button>
            </form>
          </div>
        </div>
      </>
    );
}
EOF

# 21. resources/js/src/pages/Home.tsx
cat << 'EOF' > resources/js/src/pages/Home.tsx
import React from "react";
import { Head, usePage } from "@inertiajs/react";
import AuthenticatedLayout from "@/layouts/AuthenticatedLayout";
import { PageProps } from "@/types";

export default function Home() {
  const { auth } = usePage<PageProps>().props;

  return (
    <AuthenticatedLayout
      user={auth?.user!}
      header={<h2 className="font-semibold text-xl text-gray-800">Добро пожаловать</h2>}
    >
      <Head title="Дашборд" />
      <div className="py-12">
        <div className="max-w-7xl mx-auto sm:px-6 lg:px-8">
          <div className="bg-white overflow-hidden shadow-sm sm:rounded-lg">
            <div className="p-6 text-gray-900">
              Привет, {auth?.user!.name}! Вы вошли в систему.
            </div>
          </div>
        </div>
      </div>
    </AuthenticatedLayout>
  );
}
EOF

# 22. bootstrap/app.php
cat << 'EOF' > bootstrap/app.php
<?php
use App\Http\Middleware\Login;

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->web(append: [
        //
        ]);
        $middleware->group('login', [
            Login::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        //
    })->create();
EOF

chmod -R 755 $PROJECT_DIR;
chown -R www-data:www-data $PROJECT_DIR;
cd $PROJECT_DIR;
#composer install; 
composer clear-cache;
composer update --lock;

npm install;
php artisan key:generate;
php artisan db:wipe;
php artisan migrate;
npm run build --verbose; 

# Выводим сообщение об успешном создании
echo "Проект успешно создан в директории '$PROJECT_DIR'!"
echo "Для запуска выполните следующие команды:"
echo "  cd $PROJECT_DIR"
echo "  composer install"
echo "  npm install"
echo "  php artisan key:generate"
echo "  php artisan migrate"
# echo "  php artisan serve"
echo "  npm run build"
echo "Не забудьте обновить .env с вашими настройками базы данных и SMTP!"
