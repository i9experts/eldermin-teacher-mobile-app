// import '../config/app_colors.dart';
import 'package:eldermin_teacher_app/core/theme/app_theme.dart';

import '../config/app_text_styles.dart';
import '../config/app_font_size.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomText extends StatelessWidget {
  final String text;
  final String fontFamily;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final TextOverflow? overflow;
  final int? maxLines;
  final FontStyle fontStyle;
  final double? height;
  final double? letterSpacing;
  final TextDecoration? textDecoration;
  final TextDirection? textDirection;
  final TextAlign? textAlign;

  const CustomText({
    super.key,
    required this.text,
    this.color = AppColors.black,
    this.fontSize = AppFontSize.extraSmall,
    this.fontWeight = FontWeight.w400,
    this.overflow,
    this.maxLines,
    this.textAlign,
    this.fontStyle = FontStyle.normal,
    this.height,
    this.letterSpacing,
    this.fontFamily = AppTextStyles.fontFamily,
    this.textDecoration,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.tr,
      textAlign: textAlign,
      overflow: overflow ?? TextOverflow.visible,
      maxLines: maxLines,
      textDirection: textDirection,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        letterSpacing: letterSpacing ?? 0.0,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        decoration: textDecoration,
        // height: height,
      ),
    );
  }
}
