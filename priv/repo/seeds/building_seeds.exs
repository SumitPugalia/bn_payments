defmodule BnApis.Seeder.Buildings do

alias BnApis.Repo
import Ecto.Query

@wakad_names [
    %{
      name: "33 Milestone",
      display_address: "Near Bhumkar Chowk"
    },
    %{
      name: "Bhandari Associates 7 Plumeria Drive",
      display_address: ""
    },
    %{
      name: "9 Avenues Co-Op. Housing Society",
      display_address: ""
    },
    %{
      name: "Aaiji Complex",
      display_address: ""
    },
    %{
      name: "Aakar Grove Society",
      display_address: ""
    },
    %{
      name: "Aarambh Society",
      display_address: "Datta Mandir Road"
    },
    %{
      name: "Aashray Society",
      display_address: ""
    },
    %{
      name: "Aayi Building",
      display_address: ""
    },
    %{
      name: "Ace Almighty",
      display_address: "Indira Clg Rd, Tathawade"
    },
    %{
      name: "Adi Horizons",
      display_address: "Yamuna Nagar Rd, Shankar Kalat Nagar"
    },
    %{
      name: "Adi Skyline",
      display_address: ""
    },
    %{
      name: "Adora",
      display_address: "B205, Near Plus 77, Vinode Vasti"
    },
    %{
      name: "AG West One",
      display_address: "Hinjwadi Road, Hinjawadi Village"
    },
    %{
      name: "Aishwarya Mayuri Regency",
      display_address: "Dange Chowk Road, Shankar Kalat Nagar"
    },
    %{
      name: "Aishwarya Residency",
      display_address: ""
    },
    %{
      name: "Ajay Residency",
      display_address: ""
    },
    %{
      name: "Akruti Saundrya",
      display_address: ""
    },
    %{
      name: "Akshar Elementa",
      display_address: "Elementa, Tathawade"
    },
    %{
      name: "Akshay Chandan",
      display_address: ""
    },
    %{
      name: "Akshay Park",
      display_address: ""
    },
    %{
      name: "Akshay Tower",
      display_address: "Sr. No. 190/3, Near Euro School On Pink City Road"
    },
    %{
      name: "Alliance Nisarg Housing Society",
      display_address: ""
    },
    %{
      name: "Alliance Nisarg Leela",
      display_address: "Shankar Kalat Nagar, Pimpri Chinchwad"
    },
    %{
      name: "Altiius Apartment",
      display_address: ""
    },
    %{
      name: "Amora Apartments",
      display_address: ""
    },
    %{
      name: "Anmol Residency",
      display_address: "H-Block, Vishnu Dev Nagar, Kaspte Vasti"
    },
    %{
      name: "Anshul Casa",
      display_address: ""
    },
    %{
      name: "Anuj Sai Srishti",
      display_address: "Venu Nagar Cotes"
    },
    %{
      name: "Anukul Residency",
      display_address: ""
    },
    %{
      name: "Apex Athena",
      display_address: "Marunge Road, Mumbai Bangalore Bypass"
    },
    %{
      name: "Arc Enclave",
      display_address: ""
    },
    %{
      name: "GK Armada Society",
      display_address: ""
    },
    %{
      name: "Aroma housing society",
      display_address: ""
    },
    %{
      name: "Ashirwad residency",
      display_address: "Deo Wada Moraya Raj Park "
    },
    %{
      name: "Astra Nandan Society",
      display_address: ""
    },
    %{
      name: "Atelier Society",
      display_address: ""
    },
    %{
      name: "Atharva Galaxy",
      display_address: ""
    },
    %{
      name: "Atharva Heritage",
      display_address: "Indira College Bus Stop"
    },
    %{
      name: "GK Atlanta 1",
      display_address: ""
    },
    %{
      name: "GK Atlanta 2",
      display_address: "Wakadkar Wasti, Survey No. 54/55"
    },
    %{
      name: "Atul Bella Vista Empress",
      display_address: "301, Datta Mandir Rd, Shankar Kalat Nagar"
    },
    %{
      name: "Atulya Blue Earth",
      display_address: ""
    },
    %{
      name: "Aum Sanskruti Casa Imperia",
      display_address: "Wakadkar Wasting Rd, Bhujbal Vasi"
    },
    %{
      name: "Aurum Platina",
      display_address: "Opp. Kala inseam, wakad"
    },
    %{
      name: "Auspicious Apartments",
      display_address: ""
    },
    %{
      name: "Avaneesh Apartment",
      display_address: ""
    },
    %{
      name: "Awate Heights",
      display_address: ""
    },
    %{
      name: "Ayush River Park View",
      display_address: ""
    },
    %{
      name: "Balaji Apartment",
      display_address: ""
    },
    %{
      name: "Bellezza",
      display_address: ""
    },
    %{
      name: "Belvarkar Lorelle",
      display_address: "Shankar Kalat Nagar, Pimpri Chinchwad"
    },
    %{
      name: "Beverly Hills",
      display_address: ""
    },
    %{
      name: "Bhagwati Royale",
      display_address: ""
    },
    %{
      name: "Bhakti Genesis",
      display_address: ""
    },
    %{
      name: "Bhama Pearl",
      display_address: ""
    },
    %{
      name: "Bhandari Latitude",
      display_address: "Off Wakad Hinjewadi Road, Sukhwani Petrol Pum"
    },
    %{
      name: "Bhoir Estate",
      display_address: ""
    },
    %{
      name: "Bhujbal Residency",
      display_address: ""
    },
    %{
      name: "Bhuvi Apartment",
      display_address: ""
    },
    %{
      name: "Bird’s County",
      display_address: ""
    },
    %{
      name: "Blue Bells",
      display_address: ""
    },
    %{
      name: "Bora Happy Homes",
      display_address: ""
    },
    %{
      name: "Bora Planet Apartments",
      display_address: ""
    },
    %{
      name: "Borse Aai",
      display_address: "Kaspate Chowk"
    },
    %{
      name: "Brahma Park",
      display_address: ""
    },
    %{
      name: "BU Bhandari Kaasp County",
      display_address: ""
    },
    %{
      name: "Saheels Calysta Society",
      display_address: ""
    },
    %{
      name: "Capital Tower",
      display_address: "Mahatma Phule Rd, Mangal Nagar"
    },
    %{
      name: "Aum Sanskruti Casa Imperia",
      display_address: "Jamdade Wasti, Wakadkar Wasti Rd"
    },
    %{
      name: "Dange CASA7",
      display_address: ""
    },
    %{
      name: "Cascade Society",
      display_address: ""
    },
    %{
      name: "Chandan Colozium",
      display_address: ""
    },
    %{
      name: "Chandrasavitri Park",
      display_address: ""
    },
    %{
      name: "Chordia Dhanraj Park Society",
      display_address: ""
    },
    %{
      name: "Costa Rica ",
      display_address: "Datta Mandir Road, Shankar Kalat Nagar"
    },
    %{
      name: "Courtyard One",
      display_address: ""
    },
    %{
      name: "Crystal Heights",
      display_address: "Near Dutta Mandir Road"
    },
    %{
      name: "Culture  Society",
      display_address: ""
    },
    %{
      name: "Dakshatanagar society",
      display_address: ""
    },
    %{
      name: "Dange Empire Building",
      display_address: ""
    },
    %{
      name: "Dedge Gulmohar Blossom",
      display_address: ""
    },
    %{
      name: "Deep Varsha",
      display_address: "Bhumkar Chowk, Near Institute of Business Management"
    },
    %{
      name: "Delta Melodies",
      display_address: ""
    },
    %{
      name: "Design Diaries",
      display_address: ""
    },
    %{
      name: "Devyani Palace",
      display_address: ""
    },
    %{
      name: "Dewdale Co-Operative Housing Society Ltd",
      display_address: " Shankar Kalat Nagar, Wakad, Pune, Maharashtra",
    },
    %{
      name: "Dhanraj Park",
      display_address: "Vishnu Dev Nagar, Pimpri-Chinchwad"
    },
    %{
      name: "Divinity Worldwide",
      display_address: ""
    },
    %{
      name: "DNV Elite Homes",
      display_address: "Tathawade, Dattwadi"
    },
    %{
      name: "DPK Birds County",
      display_address: ""
    },
    %{
      name: "Durwankur Park Apartment",
      display_address: ""
    },
    %{
      name: "Echoing Greens",
      display_address: "Wakad Road, Shankar Kalat Nagar"
    },
    %{
      name: "Edenn Tower Co-Housing Society",
      display_address: "Pimpri Chinchwad"
    },
    %{
      name: "Eisha Footprints",
      display_address: "Mumbai Pune By-pass road"
    },
    %{
      name: "Eisha Zenith",
      display_address: "Survey no. 89/2B, Tathawade"
    },
    %{
      name: "Elite Homes Society",
      display_address: "Tathawade"
    },
    %{
      name: "Elysium",
      display_address: ""
    },
    %{
      name: "Emerald",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Erica",
      display_address: ""
    },
    %{
      name: "Essen Shonest Towers",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Florencia Society",
      display_address: ""
    },
    %{
      name: "Fortune 108",
      display_address: "Condominium Complex"
    },
    %{
      name: "G Orbit Heritage",
      display_address: ""
    },
    %{
      name: "Gagangiri Dreamland",
      display_address: "Kaspate wasti"
    },
    %{
      name: "Gaikwad Atharva Heritage",
      display_address: ""
    },
    %{
      name: "Galaxy  SAG",
      display_address: ""
    },
    %{
      name: "Ganga Aurum Park",
      display_address: ""
    },
    %{
      name: "Ganga Cypress",
      display_address: ""
    },
    %{
      name: "Garve Amora Homes",
      display_address: ""
    },
    %{
      name: "Gauree Space Star Woods",
      display_address: ""
    },
    %{
      name: "Gawade Emerald",
      display_address: ""
    },
    %{
      name: "Gawade Emerald 3",
      display_address: ""
    },
    %{
      name: "Gayatrree Landmarks Phase 2",
      display_address: ""
    },
    %{
      name: "Giriraj Grandiose",
      display_address: ""
    },
    %{
      name: "Giriraj Maxima",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "GK Vedanta",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Gokhale Waves",
      display_address: ""
    },
    %{
      name: "Gold Finger Avenir",
      display_address: ""
    },
    %{
      name: "Golden Blessings",
      display_address: ""
    },
    %{
      name: "Golden Cascade",
      display_address: "Shedge Vasti, Shankar Kalat Nagar"
    },
    %{
      name: "Goldfinger Avenir",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Goldville Hsg. Society",
      display_address: ""
    },
    %{
      name: "Golecha Ethos",
      display_address: ""
    },
    %{
      name: "Gracia Society",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Grand Heritage",
      display_address: ""
    },
    %{
      name: "GRD Gaurav Pride",
      display_address: ""
    },
    %{
      name: "Green House",
      display_address: ""
    },
    %{
      name: "Green Space Society",
      display_address: ""
    },
    %{
      name: "Green Valley Society",
      display_address: "Kaspate Vasti Rd, Pimpri-Chinchwad"
    },
    %{
      name: "Icon Linera",
      display_address: "Karpe Nagar, Bhumkar Nagar"
    },
    %{
      name: "Icon Windsor Apartments",
      display_address: ""
    },
    %{
      name: "Icon Windsor Park",
      display_address: "Shankar Kalat Nagar, Datta mandir road"
    },
    %{
      name: "Insignia",
      display_address: ""
    },
    %{
      name: "Jai Ganesh Olympia ",
      display_address: "Near Bhumkar Chowk"
    },
    %{
      name: "Jai Malhar Apartment",
      display_address: ""
    },
    %{
      name: "Janaki Smruti",
      display_address: ""
    },
    %{
      name: "Jay Ganesh Sadan",
      display_address: ""
    },
    %{
      name: "Jignesh Apartment ",
      display_address: ""
    },
    %{
      name: "Jogle White Leaf",
      display_address: ""
    },
    %{
      name: "Kadam Kohinoor Residency",
      display_address: ""
    },
    %{
      name: "Kalp Avenue",
      display_address: "Bhumkar Chauk, Shankar Kalat Nagar"
    },
    %{
      name: "Kalpataru Crescendo",
      display_address: "Kaspte wasti"
    },
    %{
      name: "Kalpataru Exquisite",
      display_address: ""
    },
    %{
      name: "Kalpataru Harmony",
      display_address: "wakad-Dange chowk, Pune-57"
    },
    %{
      name: "Kalpataru Splendour",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Kalpavruksha Eros Meadows",
      display_address: "Kaspate wasti, new DP road"
    },
    %{
      name: "Kanchan Eleena",
      display_address: ""
    },
    %{
      name: "Kasturi Apostrophe Next",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Kasturi Epitome",
      display_address: "Shankar Kalat Nagar, Wakad"
    },
    %{
      name: "Katke Apartments",
      display_address: "Near Shiv Colony, Dutta Mandir Road"
    },
    %{
      name: "Kawade Patil Homewood",
      display_address: ""
    },
    %{
      name: "Khinvasara Samarth Carina",
      display_address: ""
    },
    %{
      name: "Kishor Platinum Towers",
      display_address: ""
    },
    %{
      name: "Kolte Patil Pink City",
      display_address: ""
    },
    %{
      name: "KPS Avenue",
      display_address: ""
    },
    %{
      name: "Krish Avenue",
      display_address: ""
    },
    %{
      name: "Krishna Heights",
      display_address: ""
    },
    %{
      name: "Krushna Kunj Society",
      display_address: ""
    },
    %{
      name: "Kshirsagar Shrine Harmony",
      display_address: ""
    },
    %{
      name: "Kumar Piccadilly",
      display_address: "Indira College Rd, Santosh Nagqr"
    },
    %{
      name: "Kundan Whitefield",
      display_address: "Swami Vivekananda nagar"
    },
    %{
      name: "La Melosa",
      display_address: "176, Opp. Star Bazar, Chaudhary Park"
    },
    %{
      name: "Lakshmi Ivana",
      display_address: "Sector No. 17/4, Wakad-Dange Chowk Road"
    },
    %{
      name: "Laxmi Apartment",
      display_address: ""
    },
    %{
      name: "L S Mehetre Laxmi Deep",
      display_address: "Datta Mandir Road"
    },
    %{
      name: "Laxmi Heights",
      display_address: "Near Mauli Chowk, Dutta Mandir Road"
    },
    %{
      name: "Legacy Square",
      display_address: ""
    },
    %{
      name: "Lifestyle Apartment",
      display_address: ""
    },
    %{
      name: "Madhu Pushpa Society",
      display_address: "Datta Mandir Rd, Shankar Kalat nagar"
    },
    %{
      name: "Madhuban Apartment",
      display_address: ""
    },
    %{
      name: "Madhupushpa",
      display_address: ""
    },
    %{
      name: "Magnova Manor",
      display_address: ""
    },
    %{
      name: "Mahalaxmi Complex",
      display_address: ""
    },
    %{
      name: "Maharshi Ashray",
      display_address: "Datta Mandir Rd, Wakad Chowk"
    },
    %{
      name: "Mahavir Bhakti Genesis",
      display_address: ""
    },
    %{
      name: "Mahindra The Woods",
      display_address: ""
    },
    %{
      name: "Maitree Sakar Apartments",
      display_address: ""
    },
    %{
      name: "Malpani Greens",
      display_address: "Survey No. 206/1/2 , Kaspate Vasti Road"
    },
    %{
      name: "Manav Silver Skyscapes",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Manav Silver Twin Decks",
      display_address: ""
    },
    %{
      name: "Mankar Florencia",
      display_address: ""
    },
    %{
      name: "Manohar Park",
      display_address: ""
    },
    %{
      name: "Mauli Residency",
      display_address: "Shankar Kalat Nagar, Pimpri Chinchwad"
    },
    %{
      name: "Mayur Park",
      display_address: ""
    },
    %{
      name: "Mayuri Apartment",
      display_address: ""
    },
    %{
      name: "Mayuri Arcade",
      display_address: "Kaspate Vasti Rd, Park Street"
    },
    %{
      name: "Mayuri Heavens Society",
      display_address: ""
    },
    %{
      name: "Mi Casa Bella",
      display_address: ""
    },
    %{
      name: "Millennium Acropolis",
      display_address: ""
    },
    %{
      name: "Miracle Mark 1",
      display_address: ""
    },
    %{
      name: "Mittal Petals",
      display_address: "S.No. 194, Kaspate Basti, Thergaon"
    },
    %{
      name: "Mont Vert One",
      display_address: "Near Wakad Chowk"
    },
    %{
      name: "Mont Vert Oystera",
      display_address: "S.No. 239 Chatrapati Chowk Rd, Mont Vert Tropez"
    },
    %{
      name: "Mont Vert Seville",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Mont Vert Sonnet",
      display_address: "Atlantis, Survey no.31, Mumbai Pune bypass"
    },
    %{
      name: "Mont Vert Tranquille",
      display_address: ""
    },
    %{
      name: "Mont Vert Tropez",
      display_address: "Mont Vert Tropez Road, Kaspate Vasti"
    },
    %{
      name: "Mont Vert Vivant",
      display_address: ""
    },
    %{
      name: "Morya Park Society",
      display_address: ""
    },
    %{
      name: "Nandadeep Apartment",
      display_address: ""
    },
    %{
      name: "Nandan Inspera",
      display_address: "Survey No. 187, Hisa No. 3/4, Datta Manrir Rd"
    },
    %{
      name: "Navdeep Society",
      display_address: ""
    },
    %{
      name: "Navjeevan Sundarban",
      display_address: ""
    },
    %{
      name: "Nirmani Apartment",
      display_address: ""
    },
    %{
      name: "Nirmiti Elite 27",
      display_address: ""
    },
    %{
      name: "Nirmiti Gracia",
      display_address: ""
    },
    %{
      name: "Nirmiti Lorelle",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Nirmiti Specia",
      display_address: ""
    },
    %{
      name: "Nisarg City 2",
      display_address: ""
    },
    %{
      name: "Nisarg City 1",
      display_address: "Nisarg City 1, Kaspate Vasti Rd, Empire Estate phase-||"
    },
    %{
      name: "Nisarg Classic",
      display_address: "Park Street"
    },
    %{
      name: "Nisarg Gandha",
      display_address: ""
    },
    %{
      name: "Nisarg Meadows",
      display_address: "Shankar Kalat Marg"
    },
    %{
      name: "Nisarg Phase II",
      display_address: ""
    },
    %{
      name: "Nisarg Pooja",
      display_address: ""
    },
    %{
      name: "Nisarg Raj",
      display_address: ""
    },
    %{
      name: "Nisarg Renuka Akruti",
      display_address: ""
    },
    %{
      name: "Nisarg Serene ",
      display_address: ""
    },
    %{
      name: "Nisarg Vishwa",
      display_address: ""
    },
    %{
      name: "NSG Royal One",
      display_address: ""
    },
    %{
      name: "Olive Orchard",
      display_address: "Pimpri Chinchwad"
    },
    %{
      name: "Om Golden Palms",
      display_address: "Golden Palms, Shankar Kalat Nagar"
    },
    %{
      name: "Om Ozone Springs",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Om The Island",
      display_address: "Datta Mandir Road"
    },
    %{
      name: "Omega Paradise Phase 2",
      display_address: ""
    },
    %{
      name: "Omega Paradise Phase 1",
      display_address: "Shankar Kalat Nagar, Pimpri Chinchwad"
    },
    %{
      name: "Opus 77",
      display_address: "Bhumkar Das Gugre Rd, Phase 1"
    },
    %{
      name: "Oxford Olympia Phase 1",
      display_address: ""
    },
    %{
      name: "Ozone Springs",
      display_address: "Pimpri Chinchwad"
    },
    %{
      name: "Padmavati Dhara",
      display_address: " Park Street wakad"
    },
    %{
      name: "Palash Plus",
      display_address: ""
    },
    %{
      name: "Palm Avenue",
      display_address: ""
    },
    %{
      name: "Paramount Altissimo",
      display_address: ""
    },
    %{
      name: "Paras Vista",
      display_address: ""
    },
    %{
      name: "Parkwayz",
      display_address: "Apartment Complex, Datta Mandir Road"
    },
    %{
      name: "Parmar Silver Nest",
      display_address: "Pimpri Chinchwad, West Pune"
    },
    %{
      name: "Mittal Petals",
      display_address: ""
    },
    %{
      name: "Pink City Housing Society",
      display_address: ""
    },
    %{
      name: "Platina Society",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Platinum Towers",
      display_address: "Shankar Nagar, Pimpri Chinchwad"
    },
    %{
      name: "Prakash Florance",
      display_address: ""
    },
    %{
      name: "Pratham Bungalow",
      display_address: ""
    },
    %{
      name: "Pride Purple Diamond Park",
      display_address: ""
    },
    %{
      name: "Pride Purple Emerald Park ",
      display_address: ""
    },
    %{
      name: "Pride Purple Park Ivory",
      display_address: "Park Street , Wisdom World School"
    },
    %{
      name: "Pride Purple Park Titanium",
      display_address: "Park street, Pimpri-Chinchwad"
    },
    %{
      name: "Pride Purple Park Turquoise",
      display_address: "Park Street, Pimpri Chinchwad"
    },
    %{
      name: "Pride Purple Ruby Park",
      display_address: "Symbiosis University"
    },
    %{
      name: "Pride Purple Sapphire Park",
      display_address: "Kalewadi Phata, Wakad"
    },
    %{
      name: "Pride Purple Topaz Park",
      display_address: "Wakad Rd, Kaspte Vasti"
    },
    %{
      name: "Pride Silver Crest",
      display_address: "Behind Siyaji Hotel, Near Bhumkar Chowk"
    },
    %{
      name: "Pristine Grandeur",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Pristine Pro Life",
      display_address: "Survey No. 170, Off Mumbai Bangalore Highway"
    },
    %{
      name: "Pristine Prolife",
      display_address: "Survey No. 170, Off Mumbai Bangalore Highway"
    },
    %{
      name: "Prudentia Towers",
      display_address: ""
    },
    %{
      name: "Pushpa Palace",
      display_address: ""
    },
    %{
      name: "Pyramid Atlante",
      display_address: ""
    },
    %{
      name: "R K Lunkad Nisarg Srushti",
      display_address: ""
    },
    %{
      name: "RADHIKA AVENUE",
      display_address: ""
    },
    %{
      name: "Radhika Enclave",
      display_address: ""
    },
    %{
      name: "Raj Palace",
      display_address: ""
    },
    %{
      name: "Rajashree Enclave",
      display_address: "Shankar Enclave Wakad"
    },
    %{
      name: "Rajeshri Society",
      display_address: "Near Apex Hospital, Kalewadi Phata"
    },
    %{
      name: "Rama Capriccio",
      display_address: "Datta Mandir Rd, Shankar Kalat"
    },
    %{
      name: "Rama Swiss County",
      display_address: "Near wisdom School"
    },
    %{
      name: "Rathi Livia",
      display_address: "Datta Mandir Rd"
    },
    %{
      name: "Regalia Apartments",
      display_address: "Yamuma Nagar Rd, Shankar Kalat Nagar"
    },
    %{
      name: "Rhythm Apartment",
      display_address: "Kaveri Nagar , Wakad"
    },
    %{
      name: "Riddhi Siddhi Heights",
      display_address: ""
    },
    %{
      name: "Rishi Olive",
      display_address: ""
    },
    %{
      name: "RK Life Space",
      display_address: ""
    },
    %{
      name: "RK Lunkad Aromatic Wind",
      display_address: "Shankar kalat nagar, Pimpri Chinchwad"
    },
    %{
      name: "RK Lunkad Housing Corporation",
      display_address: "Nisarg Pooja, Survey No.-257/1/4, Aundh"
    },
    %{
      name: "RK Lunkad Nisarg City 1",
      display_address: ""
    },
    %{
      name: "RK Lunkad Nisarg City II",
      display_address: ""
    },
    %{
      name: "RK Lunkad Nisarg Rainbow",
      display_address: ""
    },
    %{
      name: "RK Residency",
      display_address: "Shankar Kalat Nagar, Pimpri-Chinchwad"
    },
    %{
      name: "Rohan Tarang",
      display_address: "DSK Ranware Chowk, Bhujbal Vasti"
    },
    %{
      name: "Royal Entrada",
      display_address: "Sr.No. 139, Opposite Ginger Hotel"
    },
    %{
      name: "Royal Glory",
      display_address: "Dange Chowk Rd, Bhumkar Nagar"
    },
    %{
      name: "Royal Grande",
      display_address: ""
    },
    %{
      name: "Royal Oak",
      display_address: "Mane Wasti, Bhunkar Nagar"
    },
    %{
      name: "Royal Sai Crest",
      display_address: ""
    },
    %{
      name: "Ruby Park",
      display_address: "Near Kalewadi Phata "
    },
    %{
      name: "Ruby Park Co-Operative Housing Society",
      display_address: ""
    },
    %{
      name: "Runwal Heritage",
      display_address: ""
    },
    %{
      name: "Sadguru Vihar",
      display_address: ""
    },
    %{
      name: "Safal Oneiro",
      display_address: ""
    },
    %{
      name: "Sahil Vighnesh",
      display_address: ""
    },
    %{
      name: "Sahil Vignesh Residency",
      display_address: ""
    },
    %{
      name: "Sai Arcade",
      display_address: "Bhujbal  Vasti"
    },
    %{
      name: "Sai Deep Park",
      display_address: ""
    },
    %{
      name: "Sai Elloura",
      display_address: ""
    },
    %{
      name: "Sai Ganesha Apartment",
      display_address: ""
    },
    %{
      name: "Sai Heritage ",
      display_address: ""
    },
    %{
      name: "Sai India Park",
      display_address: ""
    },
    %{
      name: "Sai Ozone Cooperative Society",
      display_address: ""
    },
    %{
      name: "Sai Ozone Society",
      display_address: "Pimpri Chinchwad"
    },
    %{
      name: "Sai Sagar Erica",
      display_address: "Wakadkar Wasti Rd"
    },
    %{
      name: "Sainath Apts",
      display_address: "Bhujale Talaw, Off Link Road, Malad West"
    },
    %{
      name: "Saivijaya Apartment",
      display_address: ""
    },
    %{
      name: "Samartha Goldville",
      display_address: ""
    },
    %{
      name: "Samriddhi Paradise",
      display_address: ""
    },
    %{
      name: "Sana Paradise",
      display_address: ""
    },
    %{
      name: "Sancheti Dreamcastle",
      display_address: ""
    },
    %{
      name: "Sanjeevani Sonchapha",
      display_address: ""
    },
    %{
      name: "Sanskriti Arcade",
      display_address: "S.No-223, Opposite PCMC School, Kaspate Wasti"
    },
    %{
      name: "Sanskriti Housing Society",
      display_address: "Kaspate Wasti"
    },
    %{
      name: "Sanskriti Society",
      display_address: ""
    },
    %{
      name: "Sanskruti Casa Poli",
      display_address: ""
    },
    %{
      name: "Santoor Apartment",
      display_address: ""
    },
    %{
      name: "Santosa Palm",
      display_address: ""
    },
    %{
      name: "Santosa Paradise",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Satyam Shivam",
      display_address: ""
    },
    %{
      name: "satyam shivam society",
      display_address: ""
    },
    %{
      name: "Saundarya Society",
      display_address: ""
    },
    %{
      name: "Seeta Smruti Apartment",
      display_address: ""
    },
    %{
      name: "Senha Kunj",
      display_address: "Chaudhari Park, Near Bhumkar Chowk "
    },
    %{
      name: "Sentosa Elysium",
      display_address: "Shankar Kalat Nagar, Pimpri Chinchwad"
    },
    %{
      name: "Sentosa Paradise",
      display_address: ""
    },
    %{
      name: "SG Florenza",
      display_address: ""
    },
    %{
      name: "Shades View Phase 1",
      display_address: ""
    },
    %{
      name: "Shades View Phase 2",
      display_address: ""
    },
    %{
      name: "Shashwatte Reflection",
      display_address: "Thergaon, Pimpri Chinchwad"
    },
    %{
      name: "Sheth Tiara",
      display_address: "S.No. 128/5, Behind Sayaji Hotel"
    },
    %{
      name: "Shiv Angan",
      display_address: ""
    },
    %{
      name: "Shiv Angan Society",
      display_address: "Kalewadi Rahatani Rd, Pimple Saudagar"
    },
    %{
      name: "Shiv Darshan Apartment",
      display_address: "Chudhary Park, Shnkar Kalat Nagar"
    },
    %{
      name: "Shiv Parvati Apartments",
      display_address: ""
    },
    %{
      name: "Shiv Pooja Apartment",
      display_address: ""
    },
    %{
      name: "Shiv Puja Apartment",
      display_address: ""
    },
    %{
      name: "Shiv Samruddhi Apartment",
      display_address: ""
    },
    %{
      name: "Shiv Shakti Apartment",
      display_address: ""
    },
    %{
      name: "Shiv Srushti",
      display_address: ""
    },
    %{
      name: "Shivam Aashiyana",
      display_address: ""
    },
    %{
      name: "Shivam Majestica CHS",
      display_address: ""
    },
    %{
      name: "Shivani Residency",
      display_address: ""
    },
    %{
      name: "Shivkunj",
      display_address: ""
    },
    %{
      name: "Shonest Towers",
      display_address: "Near Omega Paradise, Datta mandir road"
    },
    %{
      name: "Shree Anand Vanketshwara Royal Castle",
      display_address: "Jai Hind Nagar, Thergaon, Pimpri Chinchwad"
    },
    %{
      name: "Shree Ganesh Imperia Apartments",
      display_address: ""
    },
    %{
      name: "Shree Mangal Wisteriaa",
      display_address: ""
    },
    %{
      name: "Shree Manibhadra ",
      display_address: "131/1b, Wakad, Opposite Wakad Police Station"
    },
    %{
      name: "Shree Manibhadra Wakad Centre",
      display_address: ""
    },
    %{
      name: "Shree Niwas",
      display_address: ""
    },
    %{
      name: "shree royal",
      display_address: ""
    },
    %{
      name: "Shree Swarup",
      display_address: ""
    },
    %{
      name: "Shri House",
      display_address: ""
    },
    %{
      name: "Shri Sankalp Apartment",
      display_address: ""
    },
    %{
      name: "Shroff Signature Heights",
      display_address: ""
    },
    %{
      name: "Shubh Mangalam Society",
      display_address: "Vivekanand Nagar, Bhumkar Chowk"
    },
    %{
      name: "Shubhamkar Heights",
      display_address: ""
    },
    %{
      name: "Shubhankar Heights",
      display_address: ""
    },
    %{
      name: "Shubhlaksh Residency",
      display_address: ""
    },
    %{
      name: "Shubhmangal Society",
      display_address: "Indira college bus stop"
    },
    %{
      name: "Shweta Darshan Housing Society",
      display_address: ""
    },
    %{
      name: "Siddhi Nisarg",
      display_address: "Bhumkar Nagar"
    },
    %{
      name: "Siddhi Raj",
      display_address: ""
    },
    %{
      name: "Siddhi Raj Apartment",
      display_address: ""
    },
    %{
      name: "Siddhivinayak Echoing Green",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Signum",
      display_address: ""
    },
    %{
      name: "Silver Orchard",
      display_address: ""
    },
    %{
      name: "Silver Skyscapes",
      display_address: "Datta Mandir Rd, Shankar Kalat Nagar"
    },
    %{
      name: "Skyline",
      display_address: "Shankar Kalat Nagar, Pimpri-Chinchwad"
    },
    %{
      name: "Skyline Apartments",
      display_address: " Shankar Kalat Nagar"
    },
    %{
      name: "Skyscraper",
      display_address: ""
    },
    %{
      name: "Sneh Avenue",
      display_address: ""
    },
    %{
      name: "Sneh Kunj",
      display_address: ""
    },
    %{
      name: "Snehangan Residency",
      display_address: ""
    },
    %{
      name: "Soham Sumy Madhurya",
      display_address: ""
    },
    %{
      name: "Solitaire Paradise",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Sonai Estate",
      display_address: ""
    },
    %{
      name: "Sonchafa",
      display_address: "S.No 75/3/2, Opp. Sant Tukaram Karyalaya"
    },
    %{
      name: "Sonesta",
      display_address: "Dange Chowk Rd, Bhumkar Nagar"
    },
    %{
      name: "Sonigara Excluzee",
      display_address: "Kasturi Chowk"
    },
    %{
      name: "Sonigara Kesar",
      display_address: "Dynasty Society, Vishnu Dev Nagar"
    },
    %{
      name: "Sonigara Laurel",
      display_address: "Mankar Chowk, Sonigara Laurel"
    },
    %{
      name: "Spacia",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "Sparklink Lamour",
      display_address: ""
    },
    %{
      name: "Sree Mangal Aishwaryam Greens",
      display_address: "Kaspate Wasti"
    },
    %{
      name: "Sri Sainath Sentosa Pearl",
      display_address: ""
    },
    %{
      name: "Sri Sri Madhuban Apartment",
      display_address: ""
    },
    %{
      name: "Sri Sri Nikunj",
      display_address: ""
    },
    %{
      name: "SS Heights",
      display_address: "Datta Mandir Road"
    },
    %{
      name: "SSD Sai Arcade",
      display_address: "Bhujbal Vasti"
    },
    %{
      name: "Starwoods",
      display_address: "Wakad, Pune"
    },
    %{
      name: "Su Casa",
      display_address: ""
    },
    %{
      name: "Submangal Society",
      display_address: "Apex hospital, Kalewadi Phata"
    },
    %{
      name: "Sucasa Society",
      display_address: "Behind Shishya School, Shankar Kalat Nagar"
    },
    %{
      name: "Sukhwani Callisto",
      display_address: ""
    },
    %{
      name: "Sukhwani Dynasty",
      display_address: ""
    },
    %{
      name: "Sukhwani Sepia",
      display_address: "Behind Indira College, Tathawadw"
    },
    %{
      name: "Sumitra Stars",
      display_address: "Kaveri Nagar, Vishnu Dev nagar"
    },
    %{
      name: "Sumitra Valley",
      display_address: ""
    },
    %{
      name: "Supreme Amadore",
      display_address: ""
    },
    %{
      name: "Swamee Keys Woods",
      display_address: ""
    },
    %{
      name: "Swapnalok Apartments",
      display_address: ""
    },
    %{
      name: "Swapnaprasad Ira Florence Apartment",
      display_address: "S.No. 192/3, Wakad-Dange Chowk Road"
    },
    %{
      name: "Swapnapurti Park",
      display_address: ""
    },
    %{
      name: "Swapnashilp Apartment",
      display_address: ""
    },
    %{
      name: "Swara Pride Residency",
      display_address: ""
    },
    %{
      name: "Swara Sparsh",
      display_address: ""
    },
    %{
      name: "Swarang Heights ",
      display_address: ""
    },
    %{
      name: "Swarnavihar Retirement Homes",
      display_address: ""
    },
    %{
      name: "Swastik Shubham Residency",
      display_address: ""
    },
    %{
      name: "Swiss County",
      display_address: "Sant Shiromani Path, Thergaon"
    },
    %{
      name: "Tanishq Jewel CHS",
      display_address: ""
    },
    %{
      name: "Tanya Apartment ",
      display_address: "Sonigera Kesar Rd, Vishnu Dev nagar"
    },
    %{
      name: "Tatvam Viviana",
      display_address: ""
    },
    %{
      name: "Tejas Harileela Apartments",
      display_address: ""
    },
    %{
      name: "The Address",
      display_address: "Near Wakad Bridge"
    },
    %{
      name: "The Almonds",
      display_address: "Kemse Vasti, Pimpri Chinchwad"
    },
    %{
      name: "The Construction Verve Residency",
      display_address: "Shankar Kalat Nagar"
    },
    %{
      name: "The Grove",
      display_address: ""
    },
    %{
      name: "The Royal Mirage",
      display_address: "Wakadkari Wasti Rd, Hinjeadi Village"
    },
    %{
      name: "The Wave Apartment",
      display_address: ""
    },
    %{
      name: "Tranquille Co-Op Housing Society",
      display_address: ""
    },
    %{
      name: "Trimurti Apartment",
      display_address: ""
    },
    %{
      name: "Tropical Palms",
      display_address: ""
    },
    %{
      name: "Twin Tower",
      display_address: ""
    },
    %{
      name: "Unicorn Nisarg Belrose",
      display_address: ""
    },
    %{
      name: "Unique Blliss ",
      display_address: "La Regalia, Akrudi Railway Station"
    },
    %{
      name: "Vaastu Viva",
      display_address: ""
    },
    %{
      name: "Vardhaman Dhruv Society",
      display_address: ""
    },
    %{
      name: "Vardhaman Dreams",
      display_address: ""
    },
    %{
      name: "Vardhman Residency",
      display_address: ""
    },
    %{
      name: "Vardhmann Aristo Apartment",
      display_address: ""
    },
    %{
      name: "Vastukalp The Onyx",
      display_address: ""
    },
    %{
      name: "Vastukalp Utkarsh",
      display_address: ""
    },
    %{
      name: "Vedant Heights",
      display_address: ""
    },
    %{
      name: "GK Vedanta",
      display_address: "S.No. 165/1 & 166/5, Pimpri Chinchwad"
    },
    %{
      name: "Venkateshawara Apartment",
      display_address: ""
    },
    %{
      name: "Verve Apartments",
      display_address: ""
    },
    %{
      name: "Vidya Apartment",
      display_address: ""
    },
    %{
      name: "Vignesh Vertex",
      display_address: ""
    },
    %{
      name: "Vilas Javdekar Palash 2i ",
      display_address: ""
    },
    %{
      name: "Vilas Javdekar Poshville",
      display_address: ""
    },
    %{
      name: "Vimal Heights",
      display_address: ""
    },
    %{
      name: "Vinode Spirea",
      display_address: ""
    },
    %{
      name: "Vishwa Vinayak Dew Dale",
      display_address: ""
    },
    %{
      name: "Vision Landmarks Subhmangalam",
      display_address: "Bhumkar Chowk, Chandramauli Garden"
    },
    %{
      name: "Vitthal Bhuvi",
      display_address: ""
    },
    %{
      name: "Vrindavan A CHS Ltd",
      display_address: ""
    },
    %{
      name: "Vrindavan Elegance",
      display_address: ""
    },
    %{
      name: "VTP Hilife",
      display_address: ""
    },
    %{
      name: "Wakad Centre",
      display_address: "Shankar Kalat Nagar, Wakad"
    },
    %{
      name: "Kolte Patil Western Avenue ",
      display_address: ""
    },
    %{
      name: "Mittal Brothers Whistling Palms",
      display_address: ""
    },
    %{
      name: "White Lily",
      display_address: "Venu Nagar Police Line, Near Pumpkin Patch school"
    },
    %{
      name: "Whitefield Apartments",
      display_address: ""
    },
    %{
      name: "Wind Chime",
      display_address: ""
    },
    %{
      name: "Windwards",
      display_address: "Chatrapati Chowk Rd, Kaspte wasti"
    },
    %{
      name: "Wisteriaa Fortune",
      display_address: "Bhumkar das gugre Rd, Bhumkar Nagar"
    },
    %{
      name: "Yash Wisteria",
      display_address: "Near Pearl Beside Latitude Society, The Island"
    },
    %{
      name: "Yashada Panache",
      display_address: ""
    },
    %{
      name: "Yashoda Serenia",
      display_address: ""
    },
    %{
      name: "Yashwant Apartment",
      display_address: ""
    },
    %{
      name: "Zenone Society",
      display_address: ""
    },
    %{
      name: "Zinnia Elegans",
      display_address: ""
    }]

@pimple_saudagar [
    %{name: "Dwarka Lords",
    display_address: ""
    },
    %{name: "Dwarkadheesh Residency",
    display_address: ""
    },
    %{name: "Mithras Park",
    display_address: ""
    },
    %{name: "Kunal Icon Co-operative Housing Society",
    display_address: ""
    },
    %{name: "S3 Lifestyle Apartments",
    display_address: ""
    },
    %{name: "Shubhashree Woods",
    display_address: ""
    },
    %{name: "Roseland Rowhouses CHS",
    display_address: ""
    },
    %{name: "Rose Woods Society",
    display_address: ""
    },
    %{name: "Rose Valley Housing Society",
    display_address: ""
    },
    %{name: "Prime Plus Housing Society",
    display_address: ""
    },
    %{name: "Rose Rhythm",
    display_address: ""
    },
    %{name: "Peace Valley Housing Society",
    display_address: ""
    },
    %{name: "Samruddhi Park",
    display_address: ""
    },
    %{name: "Rose County Co Operative Housing Society",
    display_address: ""
    },
    %{name: "Atul Alcove",
    display_address: ""
    },
    %{name: "Shiva Heights - 2",
    display_address: ""
    },
    %{name: "Sai Pearl",
    display_address: ""
    },
    %{name: "Lakshadeep Palace",
    display_address: ""
    },
    %{name: "Siddhivinayak Ginger Society",
    display_address: ""
    },
    %{name: "Planet Millennium Society",
    display_address: ""
    },
    %{name: "BlueWoods",
    display_address: ""
    },
    %{name: "Vision Boulevard",
    display_address: ""
    },
    %{name: "Sai Vision Society",
    display_address: ""
    },
    %{name: "Sai Ambience Society ",
    display_address: ""
    },
    %{name: "Kundan Estate",
    display_address: ""
    },
    %{name: "Daffodils Housing Society",
    display_address: ""
    },
    %{name: "Varuna Residency",
    display_address: ""
    },
    %{name: "Prasanna Aaras Apartment",
    display_address: ""
    },
    %{name: "Shraddha Heritage",
    display_address: ""
    },
    %{name: "Sai Dreams CHS",
    display_address: ""
    },
    %{name: "Tushar Gardens",
    display_address: ""
    },
    %{name: "Simran Corner",
    display_address: ""
    },
    %{name: "Ganesh Park",
    display_address: ""
    },
    %{name: "RadhaiNagari Co. Hsc",
    display_address: ""
    },
    %{name: "SUKHWANI CELAENO",
    display_address: ""
    },
    %{name: "Yashada Triose",
    display_address: ""
    },
    %{name: "Jhulelal Towers",
    display_address: ""
    },
    %{name: "Sai Nisarg Park",
    display_address: ""
    },
    %{name: "Shubham Society",
    display_address: ""
    },
    %{name: "Sai Nisarg Park Phase 2",
    display_address: ""
    },
    %{name: "Akshay Classic",
    display_address: ""
    },
    %{name: "Ganesham Phase 1",
    display_address: ""
    },
    %{name: "Ganeesham Phase 2",
    display_address: ""
    },
    %{name: "Sai Orchards Co-operative Housing Society Limited",
    display_address: ""
    },
    %{name: "Namrata Satellite",
    display_address: ""
    },
    %{name: "Saigarden Society",
    display_address: ""
    },
    %{name: "Kingston Avenue",
    display_address: ""
    },
    %{name: "Sukhwani Elmwoods",
    display_address: ""
    },
    %{name: "Treasure Island",
    display_address: ""
    },
    %{name: "Palm Breeze",
    display_address: ""
    },
    %{name: "Rose Icon Co-Operative Housing Society Ltd.",
    display_address: ""
    },
    %{name: "Rajveer Palace Phase 1",
    display_address: ""
    },
    %{name: "Rajveer Palace Phase 2 ",
    display_address: ""
    },
    %{name: "Sai Platinum Society",
    display_address: ""
    },
    %{name: "Jarvari Apartments",
    display_address: ""
    },
    %{name: "Vivanta life Veronika",
    display_address: ""
    },
    %{name: "Sai Paradise Apartments",
    display_address: ""
    },
    %{name: "Eclectica Home",
    display_address: ""
    },
    %{name: "Yashodevi Avenue",
    display_address: ""
    },
    %{name: "Bhojwani HI Face",
    display_address: ""
    },
    %{name: "Lifeville",
    display_address: ""
    },
    %{name: "Roseland Residency",
    display_address: ""
    },
    %{name: "Prime Square Society",
    display_address: ""
    },
    %{name: "Shree Ji Vihar",
    display_address: ""
    },
    %{name: "Sai Avenue Co-op Housing Society",
    display_address: ""
    },
    %{name: "Sai krupa housing society ",
    display_address: ""
    },
    %{name: "Jaydeep Residency Co-operative Housing Society",
    display_address: ""
    },
    %{name: "Gharonda Co Operative Housing Society",
    display_address: ""
    },
    %{name: "Nisarg Nirmiti Housing Society",
    display_address: ""
    },
    %{name: "Nisarg Nirman CHS",
    display_address: ""
    },
    %{name: "Deepmala Society",
    display_address: ""
    },
    %{name: "Sai Marigold",
    display_address: "Sai Marigold Society, Opp. Healing Touch Hospital, Kokane Chowk, Pimple Saudagar, Deepmala Society, Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Tushar Residency society",
    display_address: ""
    },
    %{name: "Laxmi Vrindavan Society",
    display_address: ""
    },
    %{name: "Vasant Avenue",
    display_address: ""
    },
    %{name: "Ganesh Residency",
    display_address: ""
    },
    %{name: "Dwarka Sai Wonders",
    display_address: ""
    },
    %{name: "Parvasaakshi Society",
    display_address: "163, 1/4, Shiv Sai Ln, Deepmala Society, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Dwarka Flora Residency Phase 1",
    display_address: "177/1 2, Shiv Sai Ln, Deepmala Society, Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Dwarka Flora Residency Phase 2",
    display_address: "Shiv Sai Ln, Deepmala Society, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Sindhu Park ",
    display_address: "Shiv Sai Ln, Deepmala Society, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Laxmi Angan Cooperative Housing Society",
    display_address: "Survey No. 174/2/1, Shiv Sai Lane, Rahatani Road,, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411017"
    },
    %{name: "Sai Saheb Society",
    display_address: "Shiv Sai Ln, Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Dwarka Sai Heritage",
    display_address: "174/3, Shiv Sai Ln, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Dwarka Sai Paradise Society",
    display_address: "Dwaraka Sai Paradise, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "The Crest",
    display_address: "Shiv Sai Ln, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Shiv Sai Vishwa",
    display_address: "opp Dwarka Flora Residency, Shiv Sai Ln, Shri Ram Colony, Pimple Saudagar, Pune, Maharash"
    },
    %{name: "Poorva Residency",
    display_address: ""
    },
    %{name: "Shivam Residency",
    display_address: "34, Shiv Sai Ln, Pimple Saudagar Gaon, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Sai Majestic Co-Operative Hosing Society",
    display_address: "34, Shiv Sai Ln, Pimple Saudagar Gaon, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Roma Galaxy Co. Op. Hsg. Society",
    display_address: "34, Shiv Sai Ln, Shri Ram Colony, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Maruti Niwas Apartment",
    display_address: ""
    },
    %{name: "Sai Vishwa",
    display_address: "Shri Ram Colony, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Bora Park",
    display_address: "Bora Park, Pimple Saudagar, Shri Ram Colony, Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Prabhat Heights",
    display_address: ""
    },
    %{name: "Sina Park ",
    display_address: ""
    },
    %{name: "Harish Classes",
    display_address: "Kalewadi - Rahatani Rd, Pawan Nagar, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Varun Park Co-operative Housing Society",
    display_address: "Varun Park, Mithila Nagari, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Ganga park",
    display_address: ""
    },
    %{name: "Harshal Apartments",
    display_address: "Harshal Apartments, Pimple Saudagar Rd, Mithila Nagari, Pimpri Sausagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Navale Residency",
    display_address: "Navale Residency, Mithila Nagari, Pimple Saudagar, Mithila Nagari, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Ashtavinayak Residency",
    display_address: "Ashtavinayak Residency, Pimple Saudagar Rd, Mithila Nagari, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Emerald Palace",
    display_address: "8/2, Pimple Saudagar Rd, Mithila Nagari, Pimpri Sausagar, Pune, Maharashtra 411027"
    },
    %{name: "Paras Rivera",
    display_address: "19, Mithila Nagari, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Ganadhish Residency",
    display_address: "19,, 19, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Sai Atharva Apartment",
    display_address: "Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Destiny Co-Op Housing Society",
    display_address: "Pimple Saudagar Rd, Near Aabacha Dhaba, Mithila Nagari, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Sai Shree",
    display_address: "Sai Shree, Pimple Saudagar Rd, Near Hotel Swaraj Garden, Mithila Nagari, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "One Nation",
    display_address: "S.No. 27, New BRT Road, Behind Hotel Swaraj Garden, Off 65m Nashik Phata Rd, Pimple Saudagar, Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Mithila Nagari HsG society",
    display_address: "Mithila Nagari, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Castalia Co. Op.HSG Soc.LTd",
    display_address: "Seven Star Lane, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Yash Sankul",
    display_address: " Yash Sankul, Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Sai Prem Park",
    display_address: "Sai Prem Park, Sai Nagar Park, Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Sai Vaastu",
    display_address: "Seven Star Lane, Off New Nasik Phata Road, Near Govind Yashada Circle, Next to SBI, Mithila Nagari, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Sai Vaibhav Society",
    display_address: "Nashik Phata Road, Sai Nagar Park, Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Kamdhenu Jasmine Cooperative Society",
    display_address: "Mithila Nagari, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Namrata Magic",
    display_address: "Nashik Phata Road, Sai Nagar Park, Pimple Saudagar, Pune, Maharashtra 411027"
    },
    %{name: "Paras Residency",
    display_address: "Paras Residency, Pimple Saudagar Rd, Sai Nagar Park, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    },
    %{name: "Gaikwad Building",
    display_address: "Gaikwad Building, Pimple Saudagar, Pimpri-Chinchwad, Maharashtra 411027"
    }]

@hinjewadi [
    %{
    name: "Rama Air Castle",
    display_address: "Allard Institute, Kasarai Road, Marunje, P-2, Hinjewadi"
    },
    %{
    name: "Ashok Meadows",
    display_address: "Rajiv Gandhi Infotech Park,p-1, Hinjewadi"
    },
    %{
    name: "Aspiria Apartment",
    display_address: "6/6/1, Opp. Shell petrol pump, P-1, Hinjewadi"
    },
    %{
    name: "Atlanta Apartments",
    display_address: "Behind Natural ice cream, near Saundarya Garden restaurant, P-2, Hinjewadi flyover"
    },
    %{
    name: "Beverly hills",
    display_address: "Bhatewara Nagar, Hinjewadi-Dange chowk road, Near IT-park, P-1, Hinjewadi"
    },
    %{
    name: "Xrbia",
    display_address: "Nerhe, Marunji Rd, P-2, Hinjewadi"
    },
    %{
    name: "Eon Homes",
    display_address: "Rajiv Gandhi Infotech Park,P-3, Maan, Hinjewadi"
    },
    %{
    name: "Global E homes",
    display_address: "P-1, Rajiv Gandhi Infotech, Hinjewadi"
    },
    %{
    name: "Kohinoor Tinsel County",
    display_address: "Plot no.-B/1, Opp. TCS Gate No.-2, Tal.Mulshi, Dist.-Bhoirwadi, P-3, Hinjewadi"
    },
    %{
    name: "Kolte Patil Green Olives",
    display_address: "P-1, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "Kolte Patil I Ven township",
    display_address: "P-2, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "Kolte Patil Iife republic",
    display_address: "Survey no.-74, P-2, Marunji, Hinjewadi"
    },
    %{
    name: "Megapolis Sangria",
    display_address: "MIDC, P-3 main Rd, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "Megapolis Smart Homes",
    display_address: "MIDC, P-3 main Rd, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "Megapolis Sparklet",
    display_address: "MIDC, P-3 main Rd, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "Megapolis Splendour",
    display_address: "MIDC, P-3 main Rd, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "Megapolis Sunway",
    display_address: "MIDC, P-3 main Rd, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "Opus 77",
    display_address: "Bhumkar Das,P-1, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "Paras Delicia",
    display_address: "Hinjewadi Village, P-2, Hinjewadi"
    },
    %{
    name: "Prapti Scrum Utkarsh",
    display_address: "201/1, P-1, Maan Road, near Le Royale, Lauran Svites, Hinjewadi"
    },
    %{
    name: "Prem Mairah Residence",
    display_address: "P-1, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "Prem Shanti Homes",
    display_address: "960, Maan, P-3, Hinjewadi"
    },
    %{
    name: "Saarthi Sovereign",
    display_address: "P-2, Hinjewadi Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "West Wind Park",
    display_address: "Sakhare Vasti Rd, P-2, Hinjewadi Village , Hinjewadi"
    },
    %{
    name: "Seetai Villa",
    display_address: "Annabhau Sathe Nagar, Maan, P-1, Hinjewadi"
    },
    %{
    name: "Sharma Willows Twin Towers",
    display_address: "P-1, Rajiv Gandhi Infotech park, Hinjewadi"
    },
    %{
    name: "TCG The crown Greens",
    display_address: "Plot no.-15, P-2, Genesis square, Rajiv Gandhi Infotech park, MIDC phase 2"
    },
    %{
    name: "Xotech Homes",
    display_address: "273, P-2, Bhatewara Nagar, Hinjewadi"
    },
    %{
    name: "Aditya Apartment",
    display_address: "140, Sakhare Vasti Rd, Phase 1, Hinjawadi Village, Hinjawadi, Pimpri-Chinchwad, Maharashtra 411057"
    },
    %{
    name: "Aristo Heights",
    display_address: "140, Sakhare Vasti Road, Hinjawadi Village, Phase 1, Hinjewadi Rajiv Gandhi Infotech Park, Hinjawadi, Pimpri-Chinchwad, Maharashtra 411057"
    },
    %{
    name: "Anjana Complex",
    display_address: "Bendre Hulawale Sakhare wasti, Sakhare Vasti Rd, Hinjawadi Village, Hinjawadi, Pimpri-Chinchwad, Maharashtra 411057"
    },
    %{
    name: "High Mont",
    display_address: "Sr. No. 277 Next to Virgo Engg. Adj. to Infosys-II, Rd, Hinjawadi Phase II, Hinjewadi Rajiv Gandhi Infotech Park, Hinjawadi, Pune, Maharashtra 411057"
    },
    %{
    name: "Tinsel Town",
    display_address: "Hinjawadi Phase II, Hinjewadi Rajiv Gandhi Infotech Park, Hinjawadi, Pimpri-Chinchwad, Maharashtra 411057"
    },
    %{
    name: "Kohinoor Tinsel County",
    display_address: "Survey No. 41/5, Plot No/B/1, Hinjewadi Phase 3, Opposite TCS Gate No. 2 Tal. Mulshi, Dist, Phase 3, Hinjewadi Rajiv Gandhi Infotech Park, Hinjawadi, Pimpri-Chinchwad, Maharashtra 411057"
    },
    %{
    name: "Megapolis Symphony",
    display_address: "Hinjewadi - Pirangut Rd, Phase 3, Hinjewadi Rajiv Gandhi Infotech Park, Hinjawadi, Pimpri-Chinchwad, Maharashtra 411057"
    },
    %{
    name: "TCG apartments Phase 2",
    display_address: "Hinjawad, Man Gao, Plot 7, Phase 2, Hinjewadi Rajiv Gandhi Infotech Park, Hinjawadi, Pune, Maharashtra 411057"
    },
    %{
    name: "Arihanta Aastha",
    display_address: "S. No. 138/2/2A, Sakhare Vasti Rd"
    },
    %{
    name: "Phase 1",
    display_address:  "Hinjewadi Rajiv Gandhi Infotech Park, Hinjawadi"
    },
    %{
    name: "Pune",
    display_address: "Maharashtra 411057"
    },
    %{
    name: "64 Green Meadows",
    display_address: "Marunji Village, Hinjawadi, Marunji, Maharashtra 411033"
    },
    %{
    name: "Sun Residency",
    display_address: "Opp. Laxmi Plaza, Behind Inn Tamanna Sakhare Vasti Rd"
    },
    %{
    name: "Phase 1",
    display_address:  "Hinjewadi Rajiv Gandhi Infotech Park, Hinjawadi"
    },
    %{
    name: "Pimpri-Chinchwad",
    display_address:  "Maharashtra 411057"
    },
    %{
    name: "Icon Viva",
    display_address: "Opposite Xion Mall, Hinjawadi Village, Hinjawadi, Pune, Maharashtra 411057"
    },
    %{
    name: "MP Residency",
    display_address: "Marunji Village, Hinjawadi, Marunji, Maharashtra 411033"
    },
    %{
    name: "Saarrthi Signor",
    display_address: "Dange Chowk Road, Wakad, Hinjewadi Phase 1, Pimpri-Chinchwad, Maharashtra 411057"
    },
    %{
    name: "Planet 9",
    display_address: "Sr. No. 141, Hinjewadi Phase I Road, Behind Symbiosis Hostel, Near Persistent Company, Sakhare Vasti Rd, Phase 1, Hinjewadi Rajiv Gandhi Infotech Park, Hinjawadi, Pimpri-Chinchwad, Maharashtra 411057"
    }
  ]

  def seed_data() do
    @wakad_names ++ @pimple_saudagar ++ @hinjewadi |>
      Enum.each(fn(%{name: name, display_address: _display_address} = building) ->
        if BnApis.Buildings.Building |> where(name: ^name) |> Repo.aggregate(:count, :id) == 0 do
          BnApis.Buildings.Building.changeset(building) |> Repo.insert!
        end
      end)
  end
end

