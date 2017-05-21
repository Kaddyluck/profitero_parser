require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'
require 'progress_bar'

CATALOG = ARGV.first
CSV_FILE = ARGV.last + ".csv"

if ARGV.length !=2
  	puts "Invalid input. Try 'ruby parser.rb category_link output_filename'"
  	exit
end

page = Nokogiri::HTML(open(CATALOG))
product_types = page.xpath('//*[@id="categories_block_left"]/div/ul/li/a')
product_types_pages = []
product_types.each { |i| product_types_pages << i['href'] }
product_types_pages.uniq!

product_page = []															# collect links for all products in all categories
puts "========== Parsing categories =========="	
category_bar = ProgressBar.new(product_types_pages.count, :bar, :counter, :eta)

product_types_pages.each do |href|
  	resp = Net::HTTP.get_response(URI.parse(href))

  	if resp.code.match(/20\d/)												# check page availability
    	quantity = Nokogiri::HTML(resp.body).								# how many products in category
    			   xpath('//*[@id="center_column"]/div[1]/div/div[2]/h1/small').
    			   text.split.map { |i| i.to_i }.max

    	if quantity <= 20													# <= 20 -> open the page in the usual way
    		product = Nokogiri::HTML(resp.body).
        			  xpath('//*[@id="center_column"]/div/div/div/div/div/div/a')

	    	product.each do |i|
	       		product_page << i['href'] unless i['href'] == "#"
    		end 

    	else																# >=20 -> GET request for show all products: ?n=#{quantity}
    		product = Nokogiri::HTML(open("#{href}?n=#{quantity}")).
        			  xpath('//*[@id="center_column"]/div/div/div/div/div/div/a')

	    	product.each do |i|
	        	product_page << i['href'] unless i['href'] == "#"
    		end
    	end 
    	category_bar.increment!

	else
    	puts "\tInvalid page, response code: #{resp.code}"
  	end
end

puts "======= Cheked! Start processing ======="
																			# collecting data from the product page
prod_title = []
prod_price = []
prod_img = []

puts "=========== Parsing products ==========="
category_bar = ProgressBar.new(product_page.count, :bar, :counter, :eta)

product_page.each do |href|
  resp = Net::HTTP.get_response(URI.parse(href))

  if resp.code.match(/20\d/)												# check page availability
    prod_img_on_page = 0													# if there are more than 2 titles and one image on the page
    
    title = Nokogiri::HTML(resp.body).										# get name of the product
    	xpath('//*[@id="breadcrumb"]/div/div/div').text
    title = title.split('>').last.strip!
    
    weight = Nokogiri::HTML(resp.body).										# get weight of the product and append it to name
    	xpath('//*[@id="attributes"]/fieldset/div/ul/li/span[@class="attribute_name"]/text()')
    
    weight.each do |w|
      prod_title << title + " - #{w}"
      prod_img_on_page += 1
    end

    price = Nokogiri::HTML(resp.body).										# get price of the product
    	xpath('//*[@id="attributes"]/fieldset/div/ul/li/span[@class="attribute_price"]/text()')
    price = price.to_s.split(/\s+/)

    price.each do |p|
      p = p.to_f
      prod_price << sprintf("%.2f",p) if p > 0
    end

    image = Nokogiri::HTML(resp.body).										# get product picture url
    	xpath('//*[@id="bigpic"]')

    image.each do |i|
      prod_img_on_page.times do
        prod_img << i['src']
      end
    end

  else
    puts "\tInvalid page, response code: #{resp.code}"
  end

  category_bar.increment!
end

CSV.open(CSV_FILE, 'wb') do |csv|											# write data to a CSV file
  prod_title.size.times do |i|
    csv << [prod_title[i], prod_price[i], prod_img[i]]
  end
end
