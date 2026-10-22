/// X岛数据结构。
/// 注意：官方接口里很多数字字段实际是字符串（getForumList / feed 尤甚），
/// 所以统一用容错解析，不要直接 `as int`。
library;

int asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

String asStr(dynamic v) => v == null ? '' : v.toString();

bool asBool(dynamic v) => asInt(v) != 0;

/// 一个串或一条回复。
class Post {
  final int id;
  final int fid;
  final int replyCount;
  final int remainReplies;
  final String img;
  final String ext;
  final String now;
  final String userHash;
  final String name;
  final String title;
  final String content;
  final bool admin;
  final bool sage;
  final List<Post> replies;

  const Post({
    required this.id,
    required this.fid,
    required this.replyCount,
    required this.remainReplies,
    required this.img,
    required this.ext,
    required this.now,
    required this.userHash,
    required this.name,
    required this.title,
    required this.content,
    required this.admin,
    required this.sage,
    required this.replies,
  });

  factory Post.fromJson(Map<String, dynamic> j) {
    final rawReplies = j['Replies'];
    return Post(
      id: asInt(j['id']),
      fid: asInt(j['fid']),
      replyCount: asInt(j['ReplyCount']),
      remainReplies: asInt(j['RemainReplies']),
      img: asStr(j['img']),
      ext: asStr(j['ext']),
      now: asStr(j['now']),
      userHash: asStr(j['user_hash']),
      name: asStr(j['name']),
      title: asStr(j['title']),
      content: asStr(j['content']),
      admin: asBool(j['admin']),
      sage: asBool(j['sage']),
      replies: rawReplies is List
          ? rawReplies
              .whereType<Map>()
              .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const <Post>[],
    );
  }

  bool get hasImage => img.isNotEmpty;

  bool get isTips => userHash == 'Tips' || title == 'Tips';

  /// 「无名氏」这种默认名不值得占一行。
  String get displayName {
    if (userHash == 'Admin') return '值班室';
    if (userHash == 'Tips') return 'Tips酱';
    if (name.isEmpty || name == '无名氏') return '无名氏';
    return name;
  }

  String get displayTitle =>
      (title.isEmpty || title == '无标题') ? '' : title;
}

class Forum {
  final int id;
  final String name;
  final int threadCount;
  final int interval;
  final String msg;

  const Forum({
    required this.id,
    required this.name,
    required this.threadCount,
    required this.interval,
    required this.msg,
  });

  factory Forum.fromJson(Map<String, dynamic> j) => Forum(
        id: asInt(j['id']),
        name: asStr(j['name']),
        threadCount: asInt(j['thread_count']),
        interval: asInt(j['interval']),
        msg: asStr(j['msg']),
      );
}

class ForumCategory {
  final int id;
  final String name;
  final List<Forum> forums;

  const ForumCategory({
    required this.id,
    required this.name,
    required this.forums,
  });

  factory ForumCategory.fromJson(Map<String, dynamic> j) => ForumCategory(
        id: asInt(j['id']),
        name: asStr(j['name']),
        forums: (j['forums'] is List)
            ? (j['forums'] as List)
                .whereType<Map>()
                .map((e) => Forum.fromJson(Map<String, dynamic>.from(e)))
                // id == -1 是「时间线」伪版面
                .where((f) => f.id > 0)
                .toList()
            : const <Forum>[],
      );
}

class TimelineLine {
  final int id;
  final String name;
  final String notice;

  const TimelineLine(this.id, this.name, this.notice);

  /// 实测：6 条线里只有综合线(1)与非创作线(3)能匿名读取，
  /// 其余会返回「必须登入领取饼干后才可以访问」。
  bool get needsCookie => !(id == 1 || id == 3);

  factory TimelineLine.fromJson(Map<String, dynamic> j) => TimelineLine(
        asInt(j['id']),
        asStr(j['name']).isEmpty ? asStr(j['display_name']) : asStr(j['name']),
        asStr(j['notice']),
      );
}

/// 当前列表的来源：时间线 or 某个版面。
class Source {
  final bool isForum;
  final int id;
  final String name;

  const Source.timeline(this.id, this.name) : isForum = false;
  const Source.forum(this.id, this.name) : isForum = true;

  String get path => isForum
      ? 'showf?id=$id&page='
      : 'timeline?id=$id&page=';
}
