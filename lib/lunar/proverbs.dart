import 'lunar_calendar.dart';

const _proverbs = [
  'Uống nước nhớ nguồn.',
  'Công cha như núi Thái Sơn, nghĩa mẹ như nước trong nguồn chảy ra.',
  'Một cây làm chẳng nên non, ba cây chụm lại nên hòn núi cao.',
  'Có công mài sắt, có ngày nên kim.',
  'Ăn quả nhớ kẻ trồng cây.',
  'Lá lành đùm lá rách.',
  'Bầu ơi thương lấy bí cùng, tuy rằng khác giống nhưng chung một giàn.',
  'Nhiễu điều phủ lấy giá gương, người trong một nước phải thương nhau cùng.',
  'Đi một ngày đàng, học một sàng khôn.',
  'Gần mực thì đen, gần đèn thì sáng.',
  'Tốt gỗ hơn tốt nước sơn.',
  'Học ăn, học nói, học gói, học mở.',
  'Thất bại là mẹ thành công.',
  'Muốn sang thì bắc cầu kiều, muốn con hay chữ thì yêu lấy thầy.',
  'Chớ thấy sóng cả mà ngã tay chèo.',
  'Ai ơi bưng bát cơm đầy, dẻo thơm một hạt đắng cay muôn phần.',
  'Kiến tha lâu cũng đầy tổ.',
  'Một con ngựa đau, cả tàu bỏ cỏ.',
  'Không thầy đố mày làm nên.',
  'Tiên học lễ, hậu học văn.',
  'Có chí thì nên.',
  'Lời nói chẳng mất tiền mua, lựa lời mà nói cho vừa lòng nhau.',
  'Nước chảy đá mòn.',
  'Một miếng khi đói bằng một gói khi no.',
  'Thuận vợ thuận chồng, tát biển Đông cũng cạn.',
  'Ở hiền gặp lành.',
  'Cái nết đánh chết cái đẹp.',
  'Ăn vóc học hay.',
  'Người ta là hoa đất.',
  'Biết thì thưa thốt, không biết thì dựa cột mà nghe.',
];

/// A proverb for [date], the same all day and different from the day before.
String proverbOf(DateTime date) => _proverbs[jdFromDateTime(date) % _proverbs.length];
