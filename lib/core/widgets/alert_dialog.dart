import 'package:flutter/material.dart';
import 'package:shamil_web_app/core/utils/colors.dart';
import 'package:shamil_web_app/core/utils/text_style.dart';

showAlertDialog(
  BuildContext context, {
  String? ok,
  String? no,
  required String title,
  void Function()? onTap,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.accentColor,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: getTitleStyle(
                    color: AppColors.primaryColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (ok != null)
                      GestureDetector(
                        onTap: onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: AppColors.accentColor,
                          ),
                          child: Text(
                            ok,
                            style: getbodyStyle(color: AppColors.primaryColor),
                          ),
                        ),
                      ),
                    if (no != null)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: AppColors.accentColor,
                          ),
                          child: Text(
                            no,
                            style: getbodyStyle(color: AppColors.primaryColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}



  // showDialog(
            //   context: context,
            //   builder: (context) {
            //     return CupertinoAlertDialog(
            //       title: const Text('تم تسجيل الحجز !'),
            //       actions: [
            //         TextButton(
            //           onPressed: () {
            //             pushAndRemoveUntil(
            //                 context, const PatientNavBarWidget());
            //           },
            //           child: const Text('اضغط للانتقال'),
            //         ),
            //         TextButton(
            //           onPressed: () {
            //             Navigator.pop(context);
            //           },
            //           child: const Text('الغاء'),
            //         ),
            //       ],
            //     );
            //   },
            // );