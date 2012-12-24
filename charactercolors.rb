# -*- coding: utf-8 -*-

$:.unshift('/home/arne/projects/analects/lib')
$:.unshift('/home/arne/github/ting/lib')

require 'ting'
require 'rmmseg'
require 'analects/cedict'
require 'json'

class ChineseParser
  Char = Struct.new(:hanzi, :pinyin, :tone)
  Word = Struct.new(:chars, :meaning)

  def initialize
    chars_dic, words_dic = '/tmp/chars.dic', '/tmp/words.dic'
    create_dict_from_cedict( chars_dic, words_dic ) unless File.exist?( chars_dic ) && File.exist?( words_dic )
    RMMSeg::Dictionary.dictionaries = [[:chars, chars_dic], [:words, words_dic]]
    RMMSeg::Dictionary.load_dictionaries
  end

  def cedict( fn = '/tmp/cedict.json' )
    unless File.exist?( fn )
      Analects::CedictLoader.download! unless File.exist? Analects::CedictLoader::LOCAL
      @cedict = Analects::CedictLoader.new( File.open( Analects::CedictLoader::LOCAL ) ).to_a
      File.open( fn, 'w' ) {|f| f << @cedict.to_json}
    end
    @cedict ||= JSON.parse IO.read( fn )
  end

  def create_dict_from_cedict( chars_dic, words_dic )
    words = []
    chars = []
    
    cedict.each do |c|
      words << c[0]
      words << c[1]
      chars += "#{c[0]}#{c[1]}".unpack('U').map{|u| [u].pack('U')}.uniq
    end
    
    histo = {}
    chars.each {|c| histo[c] ||= 0 ; histo[c]+=1 }
    
    File.open(words_dic, 'w') do |f|
      f << words.uniq.sort.map {|w| "%d %s\n" % [w.length, w]}.join
    end
    File.open(chars_dic, 'w') do |f|
      f << histo.map{|ch, cnt| "%d %s\n" % [ cnt, ch ]}.join
    end
  end

  def cedicthsh
    @cedicthsh ||= {}
    cedict.each do |c|
      c.take(2).uniq.each do |hz|
        @cedicthsh[hz] ||= []
        @cedicthsh[hz] << c
      end
    end if @cedicthsh.empty?
    @cedicthsh
  end


  def tokenize( str )
    [].tap do |result|
      RMMSeg::Algorithm.new( str ).tap do |alg|
        until (tok = alg.next_token).nil?
          result << tok.text.force_encoding('UTF-8')
        end
      end
    end
  end

  def parse( str )
    tokenize(str).map do |hz| 
      cd = cedicthsh[hz].first
      syllables = Ting.reader(:hanyu, :numbers) << cd[2].downcase
      writer = Ting.writer(:hanyu, :accents)
      chars = syllables.map.with_index do |s,idx| 
        Char.new(hz.chars.to_a[idx], (writer << s), s.tone)
      end
      Word.new( chars  , cd[3] )
    end
  end
end


def word_html( word )
  '<div class="word">' + pinyin_html(word.chars) + hanzi_html(word.chars) + 
  '<span class="translation">' + word.meaning.split('/')[1] + '</span></div>'
end

def pinyin_html( chars )
  '<span class="pinyin">' +
  chars.map do |ch|
    '<span class="tone tone-'+ch.tone.to_s+'">'+ch.pinyin+'</span>'
  end.join + '</span>'
end

def hanzi_html( chars )
  '<span class="hanzi">' +
  chars.map do |ch|
    '<span class="tone tone-'+ch.tone.to_s+'">'+ch.hanzi+'</span>'
  end.join + '</span>'
end


str = '選擇在晴空萬里的這一天
我背著釣竿獨自走到了東海岸
徜徉在海邊享受大自然的清新
忘卻所有的煩憂心情放得好輕鬆

雲兒在天上飄
鳥兒在空中飛
魚兒在水裡游
依偎在碧海藍天
悠遊自在的我
好滿足此刻的擁有'

html = ChineseParser.new.parse(str).map do |word|
  word_html(word)
end.join

File.open('/tmp/out.html','w') {|f|
  f << %|<style type="text/css">
  body {
    font-family: "Helvetica", "Arial", "sans-serif";
  }

  .word {
    display: inline-block;
    padding: 1em;
    //margin: 0 0.3em;
    //border: 1px dashed grey;
  }
  .pinyin, .hanzi, .translation {
    display: block;
    text-align: center;
  }
  .hanzi {
    font-size: 300%;
  }
  .translation {
    font-size: 70%;
  }

  .tone-1 { color: #ff0000; }
  .tone-2 { color: #d89000; }
  .tone-3 { color: #00a000; }
  .tone-4 { color: #0000ff; }

  #word-1 .pinyin, #word-1 .translation { visibility: hidden; }
  #word-2 .pinyin, #word-2 .translation { visibility: hidden; }
  #word-2 .hanzi .tone { color: black; }
  #word-4 .pinyin, #word-4 .translation { visibility: hidden; }
  #word-4 .hanzi .tone { color: black; }
  #word-5 .pinyin, #word-5 .translation { visibility: hidden; }
  #word-5 .hanzi .tone { color: black; }
  #word-7 .pinyin, #word-7 .translation { visibility: hidden; }
  #word-7 .hanzi .tone { color: black; }

  #word-3 {
    border-radius: 20%;  
    background-color: #eeeeff;
  }
</style>

#{html}
|
}


