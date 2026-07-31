class Candidate {
  Candidate({required this.id, required this.name, required this.sortOrder, this.votes = 0});
  final String id;
  final String name;
  final int sortOrder;
  final int votes;

  factory Candidate.fromJson(Map<String, dynamic> json) => Candidate(
        id: json['id'].toString(),
        name: (json['name'] ?? '').toString(),
        sortOrder: (json['sortOrder'] ?? 0) as int,
        votes: (json['votes'] ?? 0) as int,
      );
}

class Election {
  Election({
    required this.code,
    required this.name,
    required this.unit,
    required this.maxChoices,
    required this.locked,
    required this.totalBallots,
    required this.candidates,
    this.ownerKey,
  });

  final String code;
  final String name;
  final String unit;
  final int maxChoices;
  final bool locked;
  final int totalBallots;
  final List<Candidate> candidates;
  final String? ownerKey;

  factory Election.fromJson(Map<String, dynamic> json) => Election(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        unit: (json['unit'] ?? '').toString(),
        maxChoices: (json['maxChoices'] ?? 1) as int,
        locked: json['locked'] == true,
        totalBallots: (json['totalBallots'] ?? 0) as int,
        candidates: ((json['candidates'] ?? []) as List)
            .map((e) => Candidate.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        ownerKey: json['ownerKey']?.toString(),
      );
}
