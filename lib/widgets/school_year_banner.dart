import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/counselor_provider.dart';
import '../config/routes.dart';

class SchoolYearBanner extends StatelessWidget {
  const SchoolYearBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CounselorProvider>(
      builder: (context, counselorProvider, child) {
        final schoolYear = counselorProvider.selectedSchoolYear;
        final isCurrentYear = _isCurrentSchoolYear(schoolYear);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCurrentYear
                  ? [Colors.blue.shade600, Colors.blue.shade400]
                  : [Colors.orange.shade600, Colors.orange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isCurrentYear ? Colors.blue : Colors.orange).shade200,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      schoolYear == 'all'
                          ? 'All School Years'
                          : 'School Year: $schoolYear',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isCurrentYear && schoolYear != 'all')
                      const Text(
                        'Historical Data',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              if (isCurrentYear && schoolYear != 'all')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'CURRENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.counselorSettings);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Change',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, color: Colors.white, size: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isCurrentSchoolYear(String schoolYear) {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final currentSY = month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
    return schoolYear == currentSY;
  }
}