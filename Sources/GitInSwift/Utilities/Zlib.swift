import Foundation
import zlib

func zlibCompress(_ data: Data) -> Data? {
    var stream = z_stream()
    deflateInit_(&stream, Z_DEFAULT_COMPRESSION, ZLIB_VERSION,
    Int32(MemoryLayout<z_stream>.size))

    // 出力バッファを確保（入力データのサイズ + 64バイト程度を目安）
    /* なぜ +64か？
        zlibの圧縮アルゴリズムは、入力データのサイズに対して一定のオーバーヘッドが発生します。
        一般的には、圧縮されたデータは元のデータよりも小さくなりますが、
        圧縮の効率や入力データの内容によっては、圧縮後のサイズが元のサイズを超えることがあります。
        そのため、出力バッファを確保する際には、入力データのサイズに対して一定の余裕を持たせることが推奨されます。
        +64バイト程度の余裕を持たせることで、圧縮されたデータが元のサイズを超える場合でも、
        バッファオーバーフローを防ぐことができます。
    */
    var output = Data(count: data.count + 64)

    // Swift MemoryをC pointerに変換して、zlibのストリーム構造体にセット
    data.withUnsafeBytes { pointer in
         stream.next_in = UnsafeMutablePointer(mutating: pointer.bindMemory(to: Bytef.self).baseAddress!) 
         }
    // 入力データのサイズをストリーム構造体にセット
    stream.avail_in = uInt(data.count)

    // zlib に圧縮したoutputをこのpointerから書き込むように指示
    output.withUnsafeMutableBytes { pointer in
        stream.next_out = pointer.bindMemory(to: Bytef.self).baseAddress!
         }
    stream.avail_out = uInt(output.count)

    // 圧縮処理を実行
    deflate(&stream, Z_FINISH)

    // リソース解放
    deflateEnd(&stream)

    /*
        最初にstreamのavail_outを入力データのサイズ + 64に設定しているため、
        deflate関数が完了した後、stream.total_outには実際に圧縮されたデータのサイズが格納されます。
        したがって、output.prefix(Int(stream.total_out))を返すことで、
        圧縮されたデータの正確なサイズを取得し、余分な未使用バッファを除外して返すことができます。

        output = [ A B C D E F G H I J K L ... empty empty empty ]
        stream.total_out = 12
        output.prefix(Int(stream.total_out)) = [ A B C D E F G H I J K L]
    */
    return output.prefix(Int(stream.total_out))
}



func zlibDecompress(_ data: Data) -> Data? {
    var stream = z_stream()
    inflateInit_(&stream, ZLIB_VERSION, Int32(MemoryLayout<z_streamp>.size))

    var output = Data(count: data.count * 10) // 解凍後のサイズは元のサイズの10倍程度を目安
    data.withUnsafeBytes {
        stream.next_in = UnsafeMutablePointer(mutating: $0.bindMemory(to: Bytef.self).baseAddress!)
    }

    stream.avail_in = uInt(data.count)
    output.withUnsafeMutableBytes {
        stream.next_out = $0.bindMemory(to: Bytef.self).baseAddress!
    }
    stream.avail_out = uInt(output.count)

    inflate(&stream, Z_FINISH)
    inflateEnd(&stream)
    
    return output.prefix(Int(stream.total_out))
}