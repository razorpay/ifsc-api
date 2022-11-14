require 'redis'
require 'json'
require 'ifsc'
require 'daru'

redis = Redis.new

class IFSCPlus < Razorpay::IFSC::IFSC
    # Returns a 4 character known code for a bank
    # TODO: Move this method to the ifsc.rb script
    # in next release
    class << self
      def get_bank_code(code)
        sublet_code = sublet_data[code]
        regular_code = code[0..3].upcase
  
        custom_sublet_data.each do |prefix, value|
          return value if (prefix == code[0..prefix.length - 1]) && (value.length == 4)
        end
        sublet_code || regular_code
      end
  
      # Gets details of banks given the bank name,
      # city and state
      def filter_banks(state = nil, city = nil, bank = nil, limit = nil, offset = nil)
  
        filtered_df = $df
  
        unless state.nil?
          filtered_df = filtered_df.where(filtered_df["STATE"].eq(state))
        end
  
        unless city.nil?
          filtered_df = filtered_df.where(filtered_df["CITY"].eq(city))
        end
  
        unless bank.nil?
          filtered_df = filtered_df.where(filtered_df["BANK"].eq(bank))
        end
  
        # default limit is 10
        # minimum limit is 1
        # maximum limit is 100
        if limit.nil?
          limit = 10
        else
          limit = [[Integer(limit),1].max(),100].min()
        end
        
        # default and minimum offset is 0
        # maximum offset is size of filtered_df
        if offset.nil?
          offset = 0
        else
          offset = [[Integer(offset),0].max(),filtered_df.size].min()
        end
  
        if offset == offset+limit-1
          # queries like row[0..0] returns a Daru::Vector not a Daru::DataFrame
          paginated_df = filtered_df.row[offset..offset+limit].first(1)
        else
          paginated_df = filtered_df.row[offset..offset+limit-1]
        end
  
        result = {"data" => paginated_df.to_a[0]}
        result["hasNext"] = limit + offset < filtered_df.size
        result["count"] = filtered_df.size
  
        return result
      end
    end
  end



keys = redis.keys("*")

imps = []
neft = []
address = []
swift = []
iso = []
upi = []
state = []
micr = []
contact = []
city = []
branch = []
district = []
rtgs = []
centre = []
codes = []
bank = []
bankcode = []

keys = keys.slice(0,10)

details = []

def bank_details(branch)
    bank_code = IFSCPlus.get_bank_code(branch)

    [IFSCPlus.bank_name_for(branch), bank_code]
end

def strtobool(str)
    case str
    when 'true'
      true
    when 'false'
      false
    else
      false
    end
end

def maybestr(str)
    return nil if str.nil?

    return nil if str.empty?

    str
end

i = 0
keys.each do |ifsc|
    #"^[A-Z]{4}0[A-Z0-9]{6}$"
    
    if ifsc.match(/^[A-Z]{4}0[A-Z0-9]{6}$/)

        lib_bank_details = bank_details(ifsc)
        bank.append(lib_bank_details[0])
        bankcode.append(lib_bank_details[1])

        detail = redis.hgetall(ifsc)
        details.append(detail)
        imps.append(strtobool(detail["IMPS"]))
        neft.append(strtobool(detail["NEFT"]))
        address.append(detail["ADDRESS"])

        swift.append(maybestr(detail["SWIFT"]))
        iso.append(detail["ISO3166"])
        upi.append(strtobool(detail["UPI"]))
        state.append(detail["STATE"])
        micr.append(maybestr(detail["MICR"]))
        contact.append(detail["CONTACT"])
        city.append(detail["CITY"])
        branch.append(detail["BRANCH"])
        district.append(detail["DISTRICT"])
        rtgs.append(strtobool(detail["RTGS"]))
        centre.append(detail["CENTRE"])
        codes.append(ifsc)
    end

    if i % 1000 == 0
        puts "finished " + i.to_s
    end
    i = i + 1

end

df = Daru::DataFrame.new(
    "BANK": bank,
    "IFSC": codes,
    "BRANCH": branch,
    "CENTRE": centre,
    "DISTRICT": district,
    "STATE": state,
    "ADDRESS": address,
    "CONTACT": contact,
    "IMPS": imps,
    "RTGS": rtgs,
    "CITY": city,
    "ISO3166": iso,
    "NEFT": neft,
    "MICR": micr,
    "UPI": upi,
    "SWIFT": swift,
    "BANKCODE": bankcode

)
# df2 = df.where(df["STATE"].eq("MAHARASHTRA"))
# df2.inspect()
puts df[:BANK]