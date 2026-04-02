import 'package:flutter/material.dart';
import 'mixins/user_service.dart';
import 'mixins/meetup_service.dart';
import 'mixins/post_service.dart';
import 'mixins/chat_service.dart';
import 'mixins/qna_service.dart';
import 'mixins/job_service.dart';
import 'mixins/marketplace_service.dart';
import 'mixins/search_service.dart';
import 'mixins/notification_service.dart';
import 'mixins/dev_service.dart';

class FirestoreService extends ChangeNotifier
    with
        UserService,
        MeetupService,
        PostService,
        ChatService,
        QnaService,
        JobService,
        MarketplaceService,
        SearchService,
        NotificationService,
        DevService {}