defmodule BnApis.Seeder.Projects do

import Ecto.Query
alias BnApis.Repo
alias BnApis.Developers.Developer
alias BnApis.Developers.Project
alias BnApis.Developers.SalesPerson


@project_connect_seed_data [ 
  %{
    "name" => "Name",
    "developer_name" => "Developer",
    "project_name" => "Project Name",
    "phone_number" => "PhoneNo",
    "rera_id" => "Rera ID",
    "designation" => "Designation"
  },
  %{
    "name" => "Palak Sharma",
    "developer_name" => "Kolte Patil",
    "project_name" => "24 K Opula",
    "phone_number" => "9158024000",
    "rera_id" => "P52100008162",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Jeet Ranpise",
    "developer_name" => "Kolte Patil",
    "project_name" => "24 K Sereno",
    "phone_number" => "8668496879",
    "rera_id" => "P52100008162",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Vijay",
    "developer_name" => "Kolte Patil",
    "project_name" => "24 K Sereno",
    "phone_number" => "7770011020",
    "rera_id" => "P52100008162",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Nilesh Survase",
    "developer_name" => "Bhandari Associates",
    "project_name" => "7 Plumeria Drive",
    "phone_number" => "8087323777",
    "rera_id" => "P52100007251",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Praveen Kumar",
    "developer_name" => "Bhandari Associates",
    "project_name" => "7 Plumeria Drive",
    "phone_number" => "8087343777",
    "rera_id" => "P52100007251",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Richa Dagde",
    "developer_name" => "Bhandari Associates",
    "project_name" => "7 Plumeria Drive",
    "phone_number" => "8087543777",
    "rera_id" => "P52100007251",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Ankita Khandelwal",
    "developer_name" => "Amanora",
    "project_name" => "Amanora Park",
    "phone_number" => "8805025089",
    "rera_id" => "P52100005062",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Vikrant Talukdar",
    "developer_name" => "Amanora",
    "project_name" => "Amanora Park",
    "phone_number" => "9922935476",
    "rera_id" => "P52100005062",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Anand",
    "developer_name" => "Anandtara Infrastructure",
    "project_name" => "Anandtara Whitefield Residency",
    "phone_number" => "8863800800",
    "rera_id" => "P52100002934",
    "designation" => "Sales Agent" 
  },
  %{
    "name" => "Vishwajit Gaikwad",
    "developer_name" => "Anandtara Infrastructure",
    "project_name" => "Anandtara Whitefield Residency",
    "phone_number" => "9960128333",
    "rera_id" => "P52100002934",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Bunty Ramteke",
    "developer_name" => "DGDL",
    "project_name" => "Anant Vyankatesh",
    "phone_number" => "8308810950",
    "rera_id" => "P52100014063",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Sunil Varma",
    "developer_name" => "Goel Ganga Developments",
    "project_name" => "Aria",
    "phone_number" => "7720060437",
    "rera_id" => "P52100001119",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Yuvraj Jain",
    "developer_name" => "VVM Group",
    "project_name" => "Atlantis City",
    "phone_number" => "9422002441",
    "rera_id" => "P52100008805",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Ritesh",
    "developer_name" => "Rachana Lifestyle",
    "project_name" => "Bela Casa",
    "phone_number" => "7770010226",
    "rera_id" => "P52100006655",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Onkar Bhujbal",
    "developer_name" => "Rachana Lifestyle",
    "project_name" => "Bela Casa",
    "phone_number" => "9922959959",
    "rera_id" => "P52100006655",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Jagdish Samtani",
    "developer_name" => "Gini Bulders",
    "project_name" => "Belvista",
    "phone_number" => "7538000333",
    "rera_id" => "P52100009213",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Suhas Pethe",
    "developer_name" => "Aditya Shagun",
    "project_name" => "Comfort Zone",
    "phone_number" => "9168656233",
    "rera_id" => "P52100001145",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Huzefa Poonawala",
    "developer_name" => "Gagan Developers",
    "project_name" => "Ela",
    "phone_number" => "9130046992",
    "rera_id" => "P52100008975",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Soumik Chakraborty",
    "developer_name" => "Gagan Developers",
    "project_name" => "Ela",
    "phone_number" => "9130046245",
    "rera_id" => "P52100008975",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Harpal Singh Jakhu",
    "developer_name" => "Aurum",
    "project_name" => "Elmenta",
    "phone_number" => "8669077701",
    "rera_id" => "P52100006776",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Arpita",
    "developer_name" => "Kasturi Developers",
    "project_name" => "Epitome",
    "phone_number" => "9545032288",
    "rera_id" => "P52100006776",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Devendra Komkar",
    "developer_name" => "Anshul Group",
    "project_name" => "Eva",
    "phone_number" => "9561484848",
    "rera_id" => "P52100007930",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Amit Shrivastava",
    "developer_name" => "Bramha Corp",
    "project_name" => "F Residence",
    "phone_number" => "9975706806",
    "rera_id" => "P52100007160",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Fagun Davda",
    "developer_name" => "Goel Ganga Developments",
    "project_name" => "Florentina",
    "phone_number" => "8308005000",
    "rera_id" => "P52100017579",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Ranawat",
    "developer_name" => "Goel Ganga Developments",
    "project_name" => "Ganga Platino",
    "phone_number" => "9552446767",
    "rera_id" => "P52100004230",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Sunita Thakare",
    "developer_name" => "Goel Ganga Group",
    "project_name" => "Gangadham Tower",
    "phone_number" => "7028017913",
    "rera_id" => "P52700017510",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Sujit Phatak",
    "developer_name" => "Goel Ganga Group",
    "project_name" => "Gangadham Tower",
    "phone_number" => "7219209738",
    "rera_id" => "P52700017510",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Firoz",
    "developer_name" => "Godrej",
    "project_name" => "Godrej 24",
    "phone_number" => "9545411331",
    "rera_id" => "P52100004188",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Ashish Agashe",
    "developer_name" => "Adani",
    "project_name" => "Green",
    "phone_number" => "9152031101",
    "rera_id" => "P52100001721",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Nishchay Kohli",
    "developer_name" => "Adani",
    "project_name" => "Green",
    "phone_number" => "9834133990",
    "rera_id" => "P52100001721",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Arwa Hussein",
    "developer_name" => "Capricon ",
    "project_name" => "Green park",
    "phone_number" => "7888028493",
    "rera_id" => "P53100000324",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Ashish Mishra",
    "developer_name" => "Ceratech",
    "project_name" => "Greens",
    "phone_number" => "8600300821",
    "rera_id" => "P52100002203",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Abhimanyu",
    "developer_name" => "Kalpataru",
    "project_name" => "Harmony",
    "phone_number" => "8237946237",
    "rera_id" => "P53100018852",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Tejpal",
    "developer_name" => "ARV",
    "project_name" => "Imperial",
    "phone_number" => "9326266708",
    "rera_id" => "P52100003459",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Abhijeet Auti",
    "developer_name" => "Godrej",
    "project_name" => "Infinity",
    "phone_number" => "9049383666",
    "rera_id" => "P52100008137",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Sayantan Sengupta",
    "developer_name" => "Godrej",
    "project_name" => "Infinity",
    "phone_number" => "8337048148",
    "rera_id" => "P52100008137",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Manoj",
    "developer_name" => "Vedant Group",
    "project_name" => "Kingstone Atlantis",
    "phone_number" => "9823098222",
    "rera_id" => "P52100000344",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Thakur",
    "developer_name" => "Kumar Builders",
    "project_name" => "Megapolis",
    "phone_number" => "9011009232",
    "rera_id" => "P52700015384",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Rajeet Batra",
    "developer_name" => "ARV ",
    "project_name" => "Newtown",
    "phone_number" => "9970331313",
    "rera_id" => "P52100001668",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Niharika Das",
    "developer_name" => "Goel Ganga Developments",
    "project_name" => "Platino",
    "phone_number" => "9552546767",
    "rera_id" => "P52100017861",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Krishna Nanwani",
    "developer_name" => "Godrej",
    "project_name" => "Prana",
    "phone_number" => "9028738908",
    "rera_id" => "P52100004227",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Prashant Jadhav",
    "developer_name" => "Godrej",
    "project_name" => "Prana",
    "phone_number" => "9158550222",
    "rera_id" => "P52100004227",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Pravin Chaudhari",
    "developer_name" => "K Raheja",
    "project_name" => "Raheja Vistas",
    "phone_number" => "7030954988",
    "rera_id" => "P52100010743",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Akhilesh Nair",
    "developer_name" => "K Raheja",
    "project_name" => "Raheja Vistas",
    "phone_number" => "9545090363",
    "rera_id" => "P52100010743",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Arun",
    "developer_name" => "K Raheja",
    "project_name" => "Raheja Vistas",
    "phone_number" => "7030954987",
    "rera_id" => "P52100010743",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Rohit",
    "developer_name" => "K Raheja",
    "project_name" => "Raheja Vistas",
    "phone_number" => "9049292523",
    "rera_id" => "P52100010743",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Vikas Sharma",
    "developer_name" => "DGDL",
    "project_name" => "Sales Head",
    "phone_number" => "9552495524",
    "rera_id" => "P52100002613",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Krishna Bagaria",
    "developer_name" => "Godrej",
    "project_name" => "Sales Head",
    "phone_number" => "9038088848",
    "rera_id" => "P52100012664",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Tejas Misal",
    "developer_name" => "Belvalkar",
    "project_name" => "Sarita vaibhav",
    "phone_number" => "9011010820",
    "rera_id" => "P52100011146",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Ankush Rawat",
    "developer_name" => "Gera Developments",
    "project_name" => "Song of Joy",
    "phone_number" => "9075009974",
    "rera_id" => "P52100018405",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Bhagat Singh Sikarwar",
    "developer_name" => "Gera Developments",
    "project_name" => "Song of Joy",
    "phone_number" => "9075001844",
    "rera_id" => "P52100018405",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Gurpreet Singh",
    "developer_name" => "Gera Developments",
    "project_name" => "Song of Joy",
    "phone_number" => "7722096445",
    "rera_id" => "P52100018405",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Ishrat Shaik",
    "developer_name" => "Gera Developments",
    "project_name" => "Song of Joy",
    "phone_number" => "9130016840",
    "rera_id" => "P52100018405",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Daniel Joseph",
    "developer_name" => "Gagan Developers",
    "project_name" => "Utopia",
    "phone_number" => "8888000060",
    "rera_id" => "P52100001994",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Rahul",
    "developer_name" => "BU Bhandari",
    "project_name" => "Vastu Viva",
    "phone_number" => "9850092553",
    "rera_id" => "P52100001275",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Anoop",
    "developer_name" => "ARP group",
    "project_name" => "Velora",
    "phone_number" => "7798699551",
    "rera_id" => "P52100002277",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Sushant Bakale",
    "developer_name" => "ABIL",
    "project_name" => "Verde",
    "phone_number" => "9075032042",
    "rera_id" => "P52700010708",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Mustafa Kachwalla",
    "developer_name" => "Axis",
    "project_name" => "Vertiga",
    "phone_number" => "8600720003",
    "rera_id" => "P52100006184",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Sushant",
    "developer_name" => "Konark Karia",
    "project_name" => "Vertue",
    "phone_number" => "09545238288",
    "rera_id" => "P52100017623",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Ashish Anthony",
    "developer_name" => "K Raheja",
    "project_name" => "Viva",
    "phone_number" => "9607974083",
    "rera_id" => "P52100010136",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Kiran",
    "developer_name" => "Aurum",
    "project_name" => "Vrundavan",
    "phone_number" => "8007471010",
    "rera_id" => "P52100009646",
    "designation" => "Sales Agent"
  },
  %{
    "name" => "Durga Charan Banerjiee",
    "developer_name" => "Amar Developers",
    "project_name" => "Westview",
    "phone_number" => "9922427002",
    "rera_id" => "P52100008023",
    "designation" => "Sales Agent"
  }
]
  def developer_project_changeset(%{
      "name" => name,
      "developer_name" => developer_name,
      "project_name" => project_name,
      "phone_number" => phone_number,
      "rera_id" => _rera_id,
      "designation" => designation
    } = _data) do
    fn() ->
      developer = case Developer |> where(name: ^developer_name) |> Repo.one do
        nil ->
          developer_changeset = Developer.changeset(%Developer{}, %{name: developer_name})
          case Repo.insert(developer_changeset) do
            {:ok, developer} ->
              developer
            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        developer ->
          developer
      end


      project = case Project |> where(name: ^project_name) |> where(developer_id: ^developer.id) |> Repo.one do
        nil ->
          project_params = %{
            name: project_name,
            developer_id: developer.id,
            display_address: "Address",
          }
          project_changeset = Project.changeset(project_params)
          case Repo.insert(project_changeset) do
            {:ok, project} ->
              project
            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        project ->
          project
      end

      query = SalesPerson 
        |> where(name: ^name) 
        |> where(phone_number: ^phone_number)
        |> where(project_id: ^project.id)

      sales_person = case query |> Repo.one do
        nil ->
          sales_person_params = %{
            name: name,
            designation: designation,
            phone_number: phone_number,
            project_id: project.id,
          }

          sales_person_changeset = SalesPerson.changeset(%SalesPerson{}, sales_person_params)
          case Repo.insert(sales_person_changeset) do
            {:ok, sales_person} ->
              sales_person
            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        sales_person ->
          sales_person
      end

      {developer, project, sales_person}
    end
  end

  def seed_data() do
    @project_connect_seed_data |>
      Enum.each(fn(seed_data) ->
        case developer_project_changeset(seed_data) |> Repo.transaction do
          {:ok, {developer, project, sales_person}} ->
            IO.inspect("Success - developer: #{developer.id}, project: #{project.id}, sales_person: #{sales_person.id},")
          {:error, changeset} ->
            IO.inspect("Error - #{changeset}")
        end
      end)
  end
end