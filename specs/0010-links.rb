
describe "links DSL" do

  it "runs" do
    sql = I_Dig_Sql.new

    sql.describe(
    <<-EOF

             link AS DEFAULT
          asker_id |  giver_id

          # sql.fields(
            # :out => :asker_id,
            # :in  => :giver_id
          # )

              screen_name
            id, screen_name

        # sql[:screen_name] = %^
          # SELECT * FROM screen_name
        # ^

                 block
          blocked  |  victim
       screen_name | screen_name
   BLOCK_SCREEN_TYPE_ID || BLOCK_OWNER_TYPE_ID
    ________  raw        ________    raw
    owner_id  ______     owner_id    ______
    ________  owner_id     owner_id    ______
    raw       ______        ________    raw

              post - block
            pinner | pub
        screen_name|screen_name
        ORDER BY created_at DESC


            follow - block
              fan  |  star
       screen_name | screen_name

                 feed
          FROM
            follow, post
          WHERE
            follow.fan = :audience_ID
          GROUP BY follow.star
          SELECT
            follow_star_screen_name,
            post.*
            max(post.pub.created_at)
    EOF
    )


    # sql.def(:block) do
      # out_in(:blocked, :victim) {
        # are  :screen_name
        # have :owner_id
      # }

      # %w[SCREEN OWNER].each { |x|
        # where(%{
                        # BLOCK_#{x}
            # ________  raw        ________    raw
            # owner_id  ______     owner_id    ______
        # })
        # .or(%{
                        # BLOCK_#{x}
          # ________  owner_id     owner_id    ______
          # raw       ______        ________    raw
        # })
      # }
    # end

    # sql.def(:post) do
      # out_in :pinner, :pub do
        # are    :screen_name
        # have   :owner_id
        # not_exists :block
      # end

      # order_by :created_at, :DESC
    # end

    # sql.def(:follow) do
      # out_in :fan, :star do
        # are    :screen_name
        # have   :owner_id
        # not_exists :block
      # end
    # end

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

