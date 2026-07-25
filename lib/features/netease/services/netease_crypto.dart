import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

abstract final class NeteaseCrypto {
  static final _random = Random.secure();
  static final _weapiKey = utf8.encode('0CoJUm6Qyw8W8jud');
  static final _weapiIv = utf8.encode('0102030405060708');
  static final _eapiKey = utf8.encode('e82ckenh8dichen8');
  static final _rsaModulus = BigInt.parse(
    'e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152'
    'b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecb'
    'da92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d81'
    '3cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7',
    radix: 16,
  );

  static Map<String, String> weapi(Map<String, dynamic> payload) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final secret = List.generate(
      16,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    final first = base64Encode(
      _aesCbc(utf8.encode(jsonEncode(payload)), _weapiKey, _weapiIv),
    );
    final params = base64Encode(
      _aesCbc(utf8.encode(first), utf8.encode(secret), _weapiIv),
    );
    final reversed = Uint8List.fromList(utf8.encode(secret).reversed.toList());
    final encrypted = _bytesToBigInt(reversed)
        .modPow(BigInt.from(65537), _rsaModulus)
        .toRadixString(16)
        .padLeft(256, '0');
    return {'params': params, 'encSecKey': encrypted};
  }

  static String eapi(String path, Map<String, dynamic> payload) {
    final apiPath = path.replaceFirst('/eapi', '/api');
    final json = jsonEncode(payload);
    final digest = _hex(
      MD5Digest().process(
        Uint8List.fromList(
          utf8.encode('nobody${apiPath}use${json}md5forencrypt'),
        ),
      ),
    );
    final message = '$apiPath-36cd479b6b5-$json-36cd479b6b5-$digest';
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters<KeyParameter, Null>(
              KeyParameter(Uint8List.fromList(_eapiKey)),
              null,
            ),
          );
    return _hex(
      cipher.process(Uint8List.fromList(utf8.encode(message))),
    ).toUpperCase();
  }

  static Uint8List _aesCbc(List<int> input, List<int> key, List<int> iv) {
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
            true,
            PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
              ParametersWithIV(
                KeyParameter(Uint8List.fromList(key)),
                Uint8List.fromList(iv),
              ),
              null,
            ),
          );
    return cipher.process(Uint8List.fromList(input));
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value;
  }

  static String _hex(Uint8List bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
