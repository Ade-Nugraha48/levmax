// ==============================================================================
// LEVMAX: ASISTEN MANAJEMEN GAYA HIDUP CERDAS (SOLO LEVELING LIFESTYLE RPG)
// File: lib/helpers/face_biometric_helper.dart
// Deskripsi: Ekstraksi Vektor Landmark Biometrik Wajah, Validasi Posisi Head Pose,
//            dan Algoritma Perhitungan Tingkat Kecocokan (Similarity Score).
// ==============================================================================

import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Model Vektor Geometri Biometrik Wajah Ternormalisasi (Scale-Invariant)
class FaceBiometricVector {
  final double eyeDistanceRatio;
  final double eyeToNoseRatio;
  final double noseToMouthRatio;
  final double mouthWidthRatio;
  final double leftEyeToMouthRatio;
  final double rightEyeToMouthRatio;
  final double faceAspectRatio;

  FaceBiometricVector({
    required this.eyeDistanceRatio,
    required this.eyeToNoseRatio,
    required this.noseToMouthRatio,
    required this.mouthWidthRatio,
    required this.leftEyeToMouthRatio,
    required this.rightEyeToMouthRatio,
    required this.faceAspectRatio,
  });

  Map<String, double> toMap() => {
    'eyeDistanceRatio': eyeDistanceRatio,
    'eyeToNoseRatio': eyeToNoseRatio,
    'noseToMouthRatio': noseToMouthRatio,
    'mouthWidthRatio': mouthWidthRatio,
    'leftEyeToMouthRatio': leftEyeToMouthRatio,
    'rightEyeToMouthRatio': rightEyeToMouthRatio,
    'faceAspectRatio': faceAspectRatio,
  };

  factory FaceBiometricVector.fromMap(Map<String, dynamic> map) => FaceBiometricVector(
    eyeDistanceRatio: (map['eyeDistanceRatio'] as num).toDouble(),
    eyeToNoseRatio: (map['eyeToNoseRatio'] as num).toDouble(),
    noseToMouthRatio: (map['noseToMouthRatio'] as num).toDouble(),
    mouthWidthRatio: (map['mouthWidthRatio'] as num).toDouble(),
    leftEyeToMouthRatio: (map['leftEyeToMouthRatio'] as num).toDouble(),
    rightEyeToMouthRatio: (map['rightEyeToMouthRatio'] as num).toDouble(),
    faceAspectRatio: (map['faceAspectRatio'] as num).toDouble(),
  );

  /// Ekstraksi rasio geometri dari objek Face ML Kit
  static FaceBiometricVector? fromFace(Face face) {
    final w = face.boundingBox.width;
    final h = face.boundingBox.height;
    if (w <= 30 || h <= 30) return null;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth]?.position;

    double dist(math.Point<int> p1, math.Point<int> p2) {
      final dx = (p1.x - p2.x).toDouble();
      final dy = (p1.y - p2.y).toDouble();
      return math.sqrt(dx * dx + dy * dy);
    }

    // Jarak antar mata (Inter-ocular distance)
    double eyeDist = (leftEye != null && rightEye != null)
        ? dist(leftEye, rightEye)
        : (w * 0.42);

    math.Point<int>? eyeCenter;
    if (leftEye != null && rightEye != null) {
      eyeCenter = math.Point<int>((leftEye.x + rightEye.x) ~/ 2, (leftEye.y + rightEye.y) ~/ 2);
    }

    // Jarak mata ke pangkal hidung
    double eyeToNose = (eyeCenter != null && nose != null)
        ? dist(eyeCenter, nose)
        : (h * 0.28);

    math.Point<int>? mouthCenter;
    if (leftMouth != null && rightMouth != null) {
      mouthCenter = math.Point<int>((leftMouth.x + rightMouth.x) ~/ 2, (leftMouth.y + rightMouth.y) ~/ 2);
    } else if (bottomMouth != null) {
      mouthCenter = bottomMouth;
    }

    // Jarak hidung ke mulut
    double noseToMouth = (nose != null && mouthCenter != null)
        ? dist(nose, mouthCenter)
        : (h * 0.24);

    // Lebar mulut
    double mouthWidth = (leftMouth != null && rightMouth != null)
        ? dist(leftMouth, rightMouth)
        : (w * 0.36);

    // Jarak mata ke sudut mulut kiri & kanan
    double leftEyeToMouth = (leftEye != null && leftMouth != null)
        ? dist(leftEye, leftMouth)
        : (h * 0.44);

    double rightEyeToMouth = (rightEye != null && rightMouth != null)
        ? dist(rightEye, rightMouth)
        : (h * 0.44);

    return FaceBiometricVector(
      eyeDistanceRatio: eyeDist / w,
      eyeToNoseRatio: eyeToNose / h,
      noseToMouthRatio: noseToMouth / h,
      mouthWidthRatio: mouthWidth / w,
      leftEyeToMouthRatio: leftEyeToMouth / h,
      rightEyeToMouthRatio: rightEyeToMouth / h,
      faceAspectRatio: w / h,
    );
  }

  /// Menghitung skor kemiripan (Similarity Score: 0.0 - 1.0) dengan vektor patokan
  double similarityWith(FaceBiometricVector baseline) {
    double totalDiff = 0.0;
    totalDiff += (eyeDistanceRatio - baseline.eyeDistanceRatio).abs() * 2.5;
    totalDiff += (eyeToNoseRatio - baseline.eyeToNoseRatio).abs() * 2.0;
    totalDiff += (noseToMouthRatio - baseline.noseToMouthRatio).abs() * 2.0;
    totalDiff += (mouthWidthRatio - baseline.mouthWidthRatio).abs() * 1.5;
    totalDiff += (leftEyeToMouthRatio - baseline.leftEyeToMouthRatio).abs() * 1.5;
    totalDiff += (rightEyeToMouthRatio - baseline.rightEyeToMouthRatio).abs() * 1.5;
    totalDiff += (faceAspectRatio - baseline.faceAspectRatio).abs() * 1.0;

    // Total bobot = 12.0
    // deviasi normal pada orang yang sama adalah < 0.25 totalDiff
    final score = 1.0 - (totalDiff / 1.8);
    return score.clamp(0.0, 1.0);
  }
}

/// Hasil evaluasi kelayakan pose & posisi wajah
class FaceQualityEvaluation {
  final bool isEligible;
  final String statusMessage;
  final FaceBiometricVector? vector;

  const FaceQualityEvaluation({
    required this.isEligible,
    required this.statusMessage,
    this.vector,
  });
}

class FaceBiometricHelper {
  /// Memeriksa kualitas frame wajah (posisi kepala, jarak, kelengkapan landmark)
  static FaceQualityEvaluation evaluateFace(Face face) {
    // 1. Cek ukuran wajah (tidak boleh terlalu jauh)
    if (face.boundingBox.width < 90 || face.boundingBox.height < 90) {
      return const FaceQualityEvaluation(
        isEligible: false,
        statusMessage: 'DEKATKAN WAJAH ANDA KE KAMERA',
      );
    }

    // 2. Cek rotasi kepala Yaw (menoleh kiri/kanan)
    final yaw = face.headEulerAngleY;
    if (yaw != null && yaw.abs() > 22) {
      return const FaceQualityEvaluation(
        isEligible: false,
        statusMessage: 'ARAHKAN WAJAH LURUS KE DEPAN KAMERA',
      );
    }

    // 3. Cek rotasi kepala Pitch (menengadah / menunduk)
    final pitch = face.headEulerAngleX;
    if (pitch != null && pitch.abs() > 22) {
      return const FaceQualityEvaluation(
        isEligible: false,
        statusMessage: 'SEJAJARKAN WAJAH DENGAN KAMERA',
      );
    }

    // 4. Cek rotasi kepala Roll (kepala miring ke samping)
    final roll = face.headEulerAngleZ;
    if (roll != null && roll.abs() > 22) {
      return const FaceQualityEvaluation(
        isEligible: false,
        statusMessage: 'POSISIKAN KEPALA TEGAK LURUS',
      );
    }

    // 5. Ekstraksi vektor biometrik
    final vector = FaceBiometricVector.fromFace(face);
    if (vector == null) {
      return const FaceQualityEvaluation(
        isEligible: false,
        statusMessage: 'STRUKTUR WAJAH KURANG JELAS, TETAP DIAM',
      );
    }

    return FaceQualityEvaluation(
      isEligible: true,
      statusMessage: 'WAJAH TERDETEKSI SECARA OPTIMAL',
      vector: vector,
    );
  }

  /// Menghitung rata-rata sejumlah vektor sampel saat proses pendaftaran/setor wajah
  static FaceBiometricVector averageVectors(List<FaceBiometricVector> samples) {
    if (samples.isEmpty) {
      return FaceBiometricVector(
        eyeDistanceRatio: 0.4,
        eyeToNoseRatio: 0.28,
        noseToMouthRatio: 0.24,
        mouthWidthRatio: 0.36,
        leftEyeToMouthRatio: 0.44,
        rightEyeToMouthRatio: 0.44,
        faceAspectRatio: 0.75,
      );
    }

    double sumEyeDist = 0;
    double sumEyeToNose = 0;
    double sumNoseToMouth = 0;
    double sumMouthWidth = 0;
    double sumLeftEyeToMouth = 0;
    double sumRightEyeToMouth = 0;
    double sumAspectRatio = 0;

    for (final v in samples) {
      sumEyeDist += v.eyeDistanceRatio;
      sumEyeToNose += v.eyeToNoseRatio;
      sumNoseToMouth += v.noseToMouthRatio;
      sumMouthWidth += v.mouthWidthRatio;
      sumLeftEyeToMouth += v.leftEyeToMouthRatio;
      sumRightEyeToMouth += v.rightEyeToMouthRatio;
      sumAspectRatio += v.faceAspectRatio;
    }

    final n = samples.length.toDouble();
    return FaceBiometricVector(
      eyeDistanceRatio: sumEyeDist / n,
      eyeToNoseRatio: sumEyeToNose / n,
      noseToMouthRatio: sumNoseToMouth / n,
      mouthWidthRatio: sumMouthWidth / n,
      leftEyeToMouthRatio: sumLeftEyeToMouth / n,
      rightEyeToMouthRatio: sumRightEyeToMouth / n,
      faceAspectRatio: sumAspectRatio / n,
    );
  }
}
