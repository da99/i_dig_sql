
describe "links DSL" do

  it "runs" do
    sql = I_Dig_Sql.new

    sql.def(<<-EOF

             link AS DEFAULT
          asker_id |  giver_id

              screen_name
            id, screen_name

                       block
                blocked  |  victim
             screen_name | screen_name
   BLOCK_SCREEN_TYPE_ID || BLOCK_OWNER_TYPE_ID
        ________  raw    |   ________    raw
      owner_id  ______   | owner_id    ______
    ________  owner_id   | owner_id    ______
    raw       ______     |  ________    raw

                  post
            pinner | pub
       screen_name | screen_name, computer
           NOT EXISTS block
        ORDER BY created_at DESC


                follow
              fan  |  star
       screen_name | screen_name
             NOT EXISTS block

                 feed
          FROM follow, post
          FOR  :audience_id
          GROUP BY follow.star
          SELECT
            follow.star_screen_name,
            post.*
            max(post.computer_created_at)
    EOF
    )

    # sql.def(:feed) do

      # get :follow, :post
      # of  :audience_id
      # group_by 'follow.star'

      # select(
        # 'follow.star.screen_name',
        # 'post.*', 
        # 'max(post.pub.created_at)'
      # )

    # end # === query

    actual = sql.to_sql(:feed)

    puts "################################"
    puts actual
    puts "################################"

    fail
    sql(actual).should == "a"
  end # === it

end # === describe "links DSL"

