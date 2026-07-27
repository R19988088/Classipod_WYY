import 'package:classipod/features/netease/models/netease_models.dart';
import 'package:classipod/features/netease/services/netease_crypto.dart';
import 'package:classipod/features/netease/services/netease_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EAPI encryption matches the reference implementation', () {
    expect(
      NeteaseCrypto.eapi('/eapi/test', {'a': 1}),
      '4DC723619A991588865191FD2F319BAD0918BC9C604E1E84A5C3578922E3A7E8'
      '810405B5500AF5BEABA2DEAB687471586CE47DE62C9D523E260A0250C7F3AC280'
      '2B572BD7B95623F10A1D55EF99B9A8C',
    );
  });

  group('NeteaseParser', () {
    test('parses QR key and every polling state', () {
      expect(NeteaseParser.qrKey({'code': 200, 'unikey': 'abc'}), 'abc');
      expect(NeteaseParser.qrStatus({'code': 800}), NeteaseQrStatus.expired);
      expect(NeteaseParser.qrStatus({'code': 801}), NeteaseQrStatus.waiting);
      expect(NeteaseParser.qrStatus({'code': 802}), NeteaseQrStatus.scanned);
      expect(NeteaseParser.qrStatus({'code': 803}), NeteaseQrStatus.confirmed);
    });

    test('parses account profile', () {
      final profile = NeteaseParser.profile({
        'code': 200,
        'profile': {
          'userId': 42,
          'nickname': 'Neri',
          'avatarUrl': 'http://image',
        },
      });

      expect(profile.id, '42');
      expect(profile.nickname, 'Neri');
      expect(profile.avatarUrl, 'https://image');
    });

    test('parses albums, playlists and podcasts', () {
      final albums = NeteaseParser.albums({
        'code': 200,
        'data': [
          {
            'dataInfo': {
              'picUrl': 'http://album',
              'data': {
                'id': 8,
                'name': 'Album',
                'size': 9,
                'artists': [
                  {'name': 'Artist'},
                ],
              },
            },
          },
        ],
      });
      final playlists = NeteaseParser.playlists({
        'code': 200,
        'playlist': [
          {
            'id': 1,
            'name': 'Mine',
            'coverImgUrl': 'http://playlist',
            'trackCount': 2,
            'creator': {'userId': 42, 'nickname': 'Neri'},
          },
        ],
      });
      final podcasts = NeteaseParser.podcasts({
        'code': 200,
        'data': {
          'list': [
            {
              'radioId': 5,
              'title': 'Talk',
              'coverUrl': 'http://podcast',
              'programCount': 4,
              'dj': {'nickname': 'DJ'},
            },
          ],
        },
      });

      expect(albums.single.kind, NeteaseCollectionKind.album);
      expect(albums.single.coverUrl, 'https://album');
      expect(playlists.single.kind, NeteaseCollectionKind.playlist);
      expect(playlists.single.subtitle, 'Neri');
      expect(podcasts.single.kind, NeteaseCollectionKind.podcast);
      expect(podcasts.single.trackCount, 4);
    });

    test('finds the private radar in recommended playlists', () {
      final radar = NeteaseParser.privateRadar({
        'code': 200,
        'recommend': [
          {'id': 1, 'name': '每日歌曲推荐'},
          {
            'id': 2,
            'name': '私人雷达 · 每日更新',
            'picUrl': 'http://radar',
            'trackCount': 30,
            'creator': {'nickname': '网易云音乐'},
          },
        ],
      });

      expect(radar.id, '2');
      expect(radar.title, '私人雷达 · 每日更新');
      expect(radar.coverUrl, 'https://radar');
      expect(radar.kind, NeteaseCollectionKind.playlist);
    });

    test('rejects recommended playlists without a private radar', () {
      expect(
        () => NeteaseParser.privateRadar({
          'code': 200,
          'recommend': [
            {'id': 1, 'name': '每日歌曲推荐'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('parses followed artists and artist songs', () {
      final artists = NeteaseParser.artists({
        'code': 200,
        'data': [
          {'id': 7, 'name': 'Singer', 'picUrl': 'http://artist'},
        ],
      });
      final songs = NeteaseParser.artistSongs({
        'code': 200,
        'songs': [
          {
            'id': 9,
            'name': 'Song',
            'ar': [
              {'name': 'Singer'},
            ],
            'al': {'name': 'Album'},
            'dt': 1234,
          },
        ],
      });

      expect(artists.single.id, '7');
      expect(artists.single.coverUrl, 'https://artist');
      expect(songs.single.title, 'Song');
    });

    test('parses regular tracks and podcast main songs', () {
      final tracks = NeteaseParser.tracks({
        'code': 200,
        'songs': [
          {
            'id': 9,
            'name': 'Song',
            'ar': [
              {'name': 'Singer'},
            ],
            'al': {'name': 'Album', 'picUrl': 'http://song'},
            'dt': 1234,
          },
        ],
      });
      final episodes = NeteaseParser.podcastTracks(
        {
          'code': 200,
          'programs': [
            {
              'name': 'Episode',
              'mainSong': {'id': 11, 'duration': 5000},
            },
          ],
        },
        const NeteaseCollection(
          id: '4',
          kind: NeteaseCollectionKind.podcast,
          title: 'Radio',
          subtitle: 'Host',
          coverUrl: 'https://cover',
        ),
      );

      expect(tracks.single.artist, 'Singer');
      expect(tracks.single.durationMs, 1234);
      expect(tracks.single.album, 'Album');
      expect(episodes.single.id, '11');
      expect(episodes.single.title, 'Episode');
    });

    test('rejects missing playback URL', () {
      expect(
        NeteaseParser.playbackUrl({
          'code': 200,
          'data': [
            {'url': 'http://audio'},
          ],
        }),
        'https://audio',
      );
      expect(
        () => NeteaseParser.playbackUrl({
          'code': 200,
          'data': [
            {'url': null, 'fee': 1},
          ],
        }),
        throwsFormatException,
      );
    });

    test('keeps equals characters in cookie values', () {
      expect(
        NeteaseParser.cookies([
          'MUSIC_U=token==; Path=/; HttpOnly',
          '__csrf=csrf; Path=/',
        ]),
        {'MUSIC_U': 'token==', '__csrf': 'csrf'},
      );
    });
  });
}
