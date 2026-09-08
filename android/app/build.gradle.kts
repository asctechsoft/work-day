plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.campany.tickgo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // applicationId thật do flavor quyết định (xem productFlavors) — mỗi
        // flavor trỏ về một Firebase project khác nhau nên KHÔNG được trùng id.
        applicationId = "com.campany.tickgo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "WorkDay"
    }

    // HAI MÔI TRƯỜNG, HAI FIREBASE PROJECT — đừng gộp lại.
    //
    //   dev     → project dev-asc (android/app/src/dev/google-services.json)
    //   product → project tick-go (android/app/google-services.json) = DỮ LIỆU THẬT
    //
    // Plugin google-services đọc file trong src/<flavor>/ trước, không thấy thì
    // mới lấy file ở gốc android/app/ — nên bản dev tự lấy dev-asc, bản product
    // lấy file gốc. `applicationId` phải khớp ĐÚNG `package_name` khai trong
    // google-services.json của project tương ứng, lệch một ký tự là Gradle báo
    // "No matching client found for package name".
    //
    // Hai applicationId khác nhau ⇒ cài song song được cả 2 app trên cùng máy,
    // dữ liệu/đăng nhập tách hẳn.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationId = "dev.asctechsoft"
            manifestPlaceholders["appLabel"] = "WorkDay Dev"
        }
        create("product") {
            dimension = "env"
            applicationId = "com.campany.tickgo"
            manifestPlaceholders["appLabel"] = "WorkDay"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
